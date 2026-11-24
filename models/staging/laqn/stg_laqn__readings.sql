-- Staging: one row per site, pollutant and hour, straight from the source.
-- Only renaming happens here; cleaning is done in the intermediate layer.

with source as (

    select * from {{ source('laqn', 'raw_readings') }}

),

renamed as (

    select
        site_code,
        species_code,
        measured_at     as measured_at_gmt,     -- the API reports GMT all year (no summer time)
        value           as concentration_ugm3,  -- micrograms per cubic metre
        loaded_at

    from source

)

select * from renamed
