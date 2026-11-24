-- Intermediate: the ten DAQI levels, each with its band and the advice for at-risk patients.
-- Built from the two seeds, so the marts never need to read seeds directly.

with bands as (

    select distinct daqi_index, band
    from {{ ref('daqi_bands') }}

),

advice as (

    select * from {{ ref('daqi_advice') }}

),

levels as (

    select
        bands.daqi_index,
        bands.band,
        bands.daqi_index >= 4       as warn_respiratory_patients,  -- Moderate or worse
        advice.advice_at_risk

    from bands
    left join advice
        on advice.band = bands.band

)

select * from levels
