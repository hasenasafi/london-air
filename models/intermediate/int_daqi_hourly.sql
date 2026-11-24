-- Intermediate: the DAQI for every site, pollutant and hour.
-- Each pollutant is averaged the way the DAQI says:
--   NO2          -> the hourly value
--   PM2.5, PM10  -> the running mean of the last 24 hours (needs 18+ of those hours, i.e. 75%)

with readings as (

    select * from {{ ref('int_readings_enriched') }}

),

bands as (

    select * from {{ ref('daqi_bands') }}

),

rolling as (

    select
        *,
        avg(concentration_ugm3) over last_24h   as mean_24h_ugm3,
        count(*)                over last_24h   as hours_in_last_24h

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
        site_type,
        latitude,
        longitude,
        species_code,
        pollutant_name,
        measured_at_gmt,
        reading_date_gmt,
        concentration_ugm3                          as hourly_ugm3,
        case
            when species_code = 'NO2'    then concentration_ugm3
            when hours_in_last_24h >= 18 then mean_24h_ugm3
        end                                         as index_concentration_ugm3,
        case
            when species_code = 'NO2' then 'Hourly value'
            else '24-hour running mean'
        end                                         as averaging_used

    from rolling

),

with_index as (

    -- pick the highest band whose lower bound the concentration has reached
    select
        for_index.*,
        bands.daqi_index

    from for_index
    left join bands
        on  bands.species_code = for_index.species_code
        and round(for_index.index_concentration_ugm3) >= bands.lower_bound_ugm3

    qualify row_number() over (
        partition by for_index.site_code, for_index.species_code, for_index.measured_at_gmt
        order by bands.daqi_index desc
    ) = 1

)

select * from with_index
