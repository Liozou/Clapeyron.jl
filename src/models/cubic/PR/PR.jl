abstract type PRModel <: ABCubicModel end

PR_SETUP = ModelOptions(
        :PR;
        supertype=PRModel,
        locations=["properties/critical.csv", "properties/molarmass.csv","SAFT/PCSAFT/PCSAFT_unlike.csv"],
        inputparams=[
            ParamField(:k, PairParam{Float64}),
            ParamField(:Tc, SingleParam{Float64}),
            ParamField(:pc, SingleParam{Float64}),
            ParamField(:Mw, SingleParam{Float64}),
        ],
        params=[
            ParamField(:a, PairParam{Float64}),
            ParamField(:b, PairParam{Float64}),
            ParamField(:Tc, SingleParam{Float64}),
            ParamField(:Pc, SingleParam{Float64}),
            ParamField(:Mw, SingleParam{Float64}),
        ],
        mappings=[
            ModelMapping([:pc], [:Pc], identity),
            ModelMapping([:_model, :Tc, :pc, :k], [:a, :b], ab_premixing)
        ],
        members=[
            ModelMember(
                :alpha,
                :PRAlpha;
                typeconstraint=:AlphaModel,
            ),
            ModelMember(
                :activity,
                :Nothing;
                typeconstraint=:ActivityModel,
                nothing_allowed=true,
            ),
            ModelMember(
                :mixing,
                :vdW1fRule;
                typeconstraint=:MixingRule,
            ),
            ModelMember(
                :idealmodel,
                :BasicIdeal;
                typeconstraint=:IdealModel,
                groupcontribution_allowed=true,
            ),
        ],
        references=["10.1021/I160057A011"],
        inputparamstype=:ABCubicInputParam,
        paramstype=:ABCubicParam,
    )

createmodel(PR_SETUP; verbose=true)
export PR

"""
    PR(components::Vector{String}; idealmodel=BasicIdeal,
    alpha = PRAlpha,
    mixing = vdW1fRule,
    activity=nothing,
    translation=NoTranslation,
    userlocations=String[],
    ideal_userlocations=String[],
    alpha_userlocations = String[],
    mixing_userlocations = String[],
    activity_userlocations = String[],
    translation_userlocations = String[],
    verbose=false)

## Input parameters
- `Tc`: Single Parameter (`Float64`) - Critical Temperature `[K]`
- `Pc`: Single Parameter (`Float64`) - Critical Pressure `[Pa]`
- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`
- `k`: Pair Parameter (`Float64`)

## Model Parameters
- `Tc`: Single Parameter (`Float64`) - Critical Temperature `[K]`
- `Pc`: Single Parameter (`Float64`) - Critical Pressure `[Pa]`
- `Mw`: Single Parameter (`Float64`) - Molecular Weight `[g/mol]`
- `a`: Pair Parameter (`Float64`)
- `b`: Pair Parameter (`Float64`)

## Input models
- `idealmodel`: Ideal Model
- `alpha`: Alpha model
- `mixing`: Mixing model
- `activity`: Activity Model, used in the creation of the mixing model.
- `translation`: Translation Model

## Description
Peng-Robinson Equation of state.
```
P = RT/(V-Nb) + a•α(T)/(V-Nb₁)(V-Nb₂)
b₁ = (1 + √2)b
b₂ = (1 - √2)b
```

## References
1. Peng, D.Y., & Robinson, D.B. (1976). A New Two-Constant Equation of State. Industrial & Engineering Chemistry Fundamentals, 15, 59-64. doi:10.1021/I160057A011
"""
PR

function ab_consts(::Type{<:PRModel})
    return 0.457235,0.077796
end

function cubic_abp(model::PRModel, V, T, z) 
    n = sum(z)
    āᾱ ,b̄, c̄ = cubic_ab(model,V,T,z,n)
    v = V/n+c̄
    _1 = one(b̄)
    denom = evalpoly(v,(-b̄*b̄,2*b̄,_1))
    p = R̄*T/(v-b̄) - āᾱ /denom
    return āᾱ, b̄, p
end

function cubic_poly(model::PRModel,p,T,z)
    a,b,c = cubic_ab(model,p,T,z)
    RT⁻¹ = 1/(R̄*T)
    A = a*p*RT⁻¹*RT⁻¹
    B = b*p*RT⁻¹
    k₀ = B*(B*(B+1.0)-A)
    k₁ = -B*(3*B+2.0) + A
    k₂ = B-1.0
    k₃ = one(A) # important to enable autodiff
    return (k₀,k₁,k₂,k₃),c
end
#=
 (-B2-2(B2+B)+A)
 (-B2-2B2-2B+A)
 (-3B2-2B+A)
=#
function a_res(model::PRModel, V, T, z,_data = data(model,V,T,z))
    n,ā,b̄,c̄ = _data
    Δ1 = 1+√2
    Δ2 = 1-√2
    ΔPRΔ = 2*√2
    RT⁻¹ = 1/(R̄*T)
    ρt = (V/n+c̄)^(-1) # translated density
    ρ  = n/V
    return -log(1+(c̄-b̄)*ρ) - ā*RT⁻¹*log((Δ1*b̄*ρt+1)/(Δ2*b̄*ρt+1))/(ΔPRΔ*b̄)

    #return -log(V-n*b̄) + āᾱ/(R̄*T*b̄*2^(3/2)) * log((2*V-2^(3/2)*b̄*n+2*b̄*n)/(2*V+2^(3/2)*b̄*n+2*b̄*n))
end

cubic_zc(::PRModel) = 0.3074
