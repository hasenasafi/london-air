-- Intermediate: the DAQI for each site, pollutant and day (the official method for past days).
--   NO2          -> the highest hourly value of the day
--   PM2.5, PM10  -> the mean of the day (only if 18+ hours were measured, i.e. 75%)

with readings as (

    select * from {{ ref('int_readings_enriched') }}

),

bands as (

    select * from {{ ref('daqi_bands') }}

),

daily as (

    select
        site_code,
        site_name,
        borough,
        site_type,
        latitude,
        longitude,
        species_code,
        pollutant_name,
        reading_date_gmt,
        count(*)                    as hours_measured,
        avg(concentration_ugm3)     as daily_mean_ugm3,
        max(concentration_ugm3)     as daily_max_hourly_ugm3

    from readings
    group by all

),

for_index as (

    select
        *,
        case
            when species_code = 'NO2' then daily_max_hourly_ugm3
            when hours_measured >= 18 then daily_mean_ugm3
        end                         as index_concentration_ugm3

    from daily

),

with_index as (

    select
        for_index.*,
        bands.daqi_index

    from for_index
    left join bands
        on  bands.species_code = for_index.species_code
        and round(for_index.index_concentration_ugm3) >= bands.lower_bound_ugm3

    qualify row_number() over (
        partition by for_index.site_code, for_index.species_code, for_index.reading_date_gmt
        order by bands.daqi_index desc
    ) = 1

)

select * from with_index
