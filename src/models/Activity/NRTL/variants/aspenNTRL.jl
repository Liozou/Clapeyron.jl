struct aspenNRTLParam <: EoSParam
    a0::PairParam{Float64}
    a1::PairParam{Float64}
    t0::PairParam{Float64}
    t1::PairParam{Float64}
    t2::PairParam{Float64}
    t3::PairParam{Float64}
end

abstract type aspenNRTLModel <: NRTLModel end

struct aspenNRTL{c<:EoSModel} <: NRTLModel
    components::Array{String,1}
    params::aspenNRTLParam
    puremodel::EoSVectorParam{c}
    references::Array{String,1}
end

@registermodel aspenNRTL

export aspenNRTL
"""
    aspenNRTL <: ActivityModel

    function aspenNRTL(components::Vector{String};
    puremodel=PR,
    userlocations=String[],
    pure_userlocations = String[],
    verbose=false)

## Input parameters
- `a0`: Pair Parameter (`Float64`, asymetrical, defaults to `0`) - Interaction Parameter
- `a1`: Pair Parameter (`Float64`, asymetrical, defaults to `0`) - Interaction Parameter
- `t0`: Pair Parameter (`Float64`, asymetrical, defaults to `0`) - Interaction Parameter
- `t1`: Pair Parameter (`Float64`, asymetrical, defaults to `0`) - Interaction Parameter
- `t2`: Pair Parameter (`Float64`, asymetrical, defaults to `0`) - Interaction Parameter
- `t3`: Pair Parameter (`Float64`, asymetrical, defaults to `0`) - Interaction Parameter

## Input models
- `puremodel`: model to calculate pure pressure-dependent properties

## Description
NRTL (Non Random Two Fluid) activity model:
```
Gᴱ = nRT∑[xᵢ(∑τⱼᵢGⱼᵢxⱼ)/(∑Gⱼᵢxⱼ)]
Gᵢⱼ exp(-αᵢⱼτᵢⱼ)
αᵢⱼ = αᵢⱼ₀ + αᵢⱼ₁T
τᵢⱼ = tᵢⱼ₀ + tᵢⱼ₁/T + tᵢⱼ₂*ln(T) + tᵢⱼ₃*T
```

## References
1. Renon, H., & Prausnitz, J. M. (1968). Local compositions in thermodynamic excess functions for liquid mixtures. AIChE journal. American Institute of Chemical Engineers, 14(1), 135–144. [doi:10.1002/aic.690140124](https://doi.org/10.1002/aic.690140124)
"""
aspenNRTL

function NRTL(components::Vector{String}; puremodel=PR,
    userlocations = String[], 
    pure_userlocations = String[],
    verbose=false)
    params = getparams(components, String[]; userlocations=userlocations, asymmetricparams=["a","b"], ignore_missing_singleparams=["a","b"], verbose=verbose)
    a0  = params["a0"]
    a1  = params["a1"]
    t0  = params["t0"]
    t1  = params["t1"]
    t2  = params["t2"]
    t3  = params["t3"]

    _puremodel = init_puremodel(puremodel,components,pure_userlocations,verbose)
    packagedparams = aspenNRTLParam(a0,a1,t0,t1,t2,t3)
    references = String["10.1002/aic.690140124"]
    model = aspenNRTL(components,packagedparams,_puremodel,references)
    return model
end

function aspenNRTL(model::NRTL)
    params = model.params
    a0 = copy(params.c)
    a1 = copy(params.a)
    a1 .= 0
    t0 = copy(params.a)
    t1 = copy(params.b)
    t2 = copy(params.a)
    t3 = copy(params.a)
    t1 .= 0
    t2 .= 0
    packagedparams = aspenNRTLParam(a0,a1,t0,t1,t2,t3)
    return NRTL(model.components,packagedparams,model.puremodel,model.references)
end
function excess_gibbs_free_energy(model::aspenNRTLModel,p,T,z)
    a₀ = model.params.a.values
    a₁  = model.params.b.values
    t₀  = model.params.c.values
    t₁  = model.params.c.values
    t₂  = model.params.c.values
    t₃  = model.params.c.values

    _0 = zero(T+first(z))
    n = sum(z)
    invn = 1/n
    invT = 1/(T)
    lnT = log(T)
    res = _0 
    for i ∈ @comps
        ∑τGx = _0
        ∑Gx = _0
        xi = z[i]*invn
        for j ∈ @comps
            xj = z[j]*invn
            α = a₀[j,i] + a₁[j,i]*T
            τji = t₀[j,i] + t₁[j,i]*invT + t₂[j,i]*lnT + t₃[j,i]*T
            Gji = exp(-α*τji)
            Gx = xj*Gji
            ∑Gx += Gx
            ∑τGx += Gx*τji
        end
        res += xi*∑τGx/∑Gx
    end
    return n*res*R̄*T
end
