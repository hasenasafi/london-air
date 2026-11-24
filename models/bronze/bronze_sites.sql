-- SILVER: monitoring sites with clear names and proper date types.

select
    site_code,
    site_name,
    site_type,
    local_authority_name                          as borough,
    latitude,
    longitude,
    cast(try_cast(date_opened as timestamp) as date) as opened_on,
    cast(try_cast(date_closed as timestamp) as date) as closed_on,
    date_closed is null                           as is_open
from {{ source('bronze', 'raw_sites') }}
