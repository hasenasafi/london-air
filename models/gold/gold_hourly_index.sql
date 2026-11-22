-- GOLD: the government Daily Air Quality Index (DAQI) for every site, pollutant and hour.
-- Each pollutant is averaged the way the DAQI says:
--   NO2          -> the hourly value
--   PM2.5, PM10  -> the running mean of the last 24 hours (needs 18+ of those hours, i.e. 75%)

with readings as (
    select * from {{ ref('silver_readings') }}
),

rolling as (
    select
        *,
        avg(concentration_ugm3) over last_24h as mean_24h_ugm3,
        count(*)                over last_24h as hours_in_last_24h
    from readings
    window last_24h as (
        partition by site_code, species_code
        order by measured_at_gmt
        range between interval 23 hours preceding and current row
    )
),

for_index as (
    select
        site_code,
        site_name,
        borough,
        species_code,
        pollutant_name,
        measured_at_gmt,
        concentration_ugm3                        as hourly_ugm3,
        case
            when species_code = 'NO2'  then concentration_ugm3
            when hours_in_last_24h >= 18 then mean_24h_ugm3
        end                                       as index_concentration_ugm3,
        case
            when species_code = 'NO2' then 'Hourly value'
            else '24-hour running mean'
        end                                       as averaging_used
    from rolling
),

bands as (
    select * from {{ ref('daqi_bands') }}
)

-- pick the highest band whose lower bound the concentration has reached
select
    f.*,
    b.daqi_index,
    b.band
from for_index f
left join bands b
    on  b.species_code = f.species_code
    and round(f.index_concentration_ugm3) >= b.lower_bound_ugm3
qualify row_number() over (
    partition by f.site_code, f.species_code, f.measured_at_gmt
    order by b.daqi_index desc
) = 1
