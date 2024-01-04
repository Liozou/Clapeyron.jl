# The following array is populated during expansion of the @unitfulaware macro. It is then
# digested in the ClapeyronUnitfulExt.jl extension
const UNITFUL_AWARE_DEFINITIONS = Expr[]

"""
```julia
@unitfulaware function pressure(model::EoSModel, V::u"m^3", T::u"K", z::AbstractVector{u"mol"}=SA[1.])::u"Pa"
    ...
end
```
"""
macro unitfulaware(expr)
    push!(UNITFUL_AWARE_DEFINITIONS, expr)
    esc(_strip_unitfulaware(expr))
end

function _strip_unitfulaware(expr::Expr)
    if !Meta.isexpr(expr, :function)
        error("@unitfulaware must be placed before a function definition in long form.")
    end
    if !Meta.isexpr(expr.args[1], :(::))
        error("The function in @unitfulaware must have a return type unit. Use `::NoUnits` if necessary.")
    end
    call = expr.args[1].args[1]
    @assert Meta.isexpr(call, :call)
    newcall = Expr(:call)
    newcall.args = map(x -> x isa Expr ? _strip_unit(x) : x, call.args)
    Expr(:function, newcall, expr.args[2])
end

function _strip_unit(expr::Expr)
    newexpr = Expr(expr.head)
    for arg in enumerate(expr.args)
        push!(newexpr.args, if !(arg isa Expr)
            arg
        elseif Meta.isexpr(arg, :macrocall) && arg.args[1] == Symbol("@u_str")
            :(<:Any)
        else
            _strip_unit(arg)
        end)
    end
    newexpr
end
