-- Staging: one row per monitoring site, straight from the source.
-- Only renaming and type-casting happens here; no joins, no business logic.

with source as (

    select * from {{ source('laqn', 'raw_sites') }}

),

renamed as (

    select
        site_code,
        site_name,
        site_type,
        local_authority_name                                as borough,
        latitude,
        longitude,
        cast(try_cast(date_opened as timestamp) as date)    as opened_on,
        cast(try_cast(date_closed as timestamp) as date)    as closed_on,
        date_closed is null                                 as is_open,
        loaded_at

    from source

)

select * from renamed
