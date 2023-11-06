@kwdef struct SelectWidget{OptionT}
    name::String
    label::String
    options::Vector{OptionT}
    default::Int=1
end

function render_options(obj::SelectWidget)
    return @htl "$((option(val) for val in obj.options))"
end

function render_stacked(obj::SelectWidget)
    return @htl """
    <div class="field-row-stacked">
      <label for="$( obj.name )">
        $( obj.label )
      </label>
      <select name="$( obj.name )" x-model.fill="f.$( obj.name )">
        $( render_options(obj) )
      </select>
    </div>
    """
end

@kwdef struct NumberWidget{NumberT}
    name::String
    label::String 
    default::Union{NumberT, Nothing}
end

function render_stacked(obj::NumberWidget)
    return @htl """
    <div class="field-row-stacked">
      <label for="$( obj.name )">
        $( obj.label )
      </label>
      <input type="number" name="$( obj.name )" value="$( obj.default )">
    </div>
    """
end

@kwdef struct CheckBoxWidget
    name::String
    label::String 
    default::Bool
end

function to_checked(val)
    if val
        return "checked" => "true"
    else
        return nothing
    end
end

function render_row(obj::CheckBoxWidget)
    return @htl """
    <div class="field-row">
      <input type="checkbox" id="$( obj.name )" name="$( obj.name )" $( to_checked(obj.default) )>
      <label for="$( obj.name )">
        $( obj.label )
      </label>
    </div>
    """
end

function confget(configs, val)
    idx = findfirst(c -> c.value == val, configs)
    if idx !== nothing
        return configs[idx]
    end
end

struct ParamParser{T}
    params::T
end

function (parse::ParamParser)(conf::AbstractVector, name, args...; kwargs...)
    desc = confget(conf, parse.params[name])
    desc.get(args...; kwargs...)
end

function (parse::ParamParser)(conf::SelectWidget, args...; kwargs...)
    desc = confget(conf.options, parse.params[conf.name])
    desc.get(args...; kwargs...)
end

function (parse::ParamParser)(conf::NumberWidget{T}, args...; kwargs...) where T
    tryparse(T, parse.params[conf.name])
end

function (parse::ParamParser)(conf::CheckBoxWidget, args...; kwargs...)
    conf.name in keys(parse.params)
end

function mk_descget(params)
    function descget(conf, name, args...; kwargs...)
        desc = confget(conf, params[name])
        desc.get(args...; kwargs...)
    end
    descget
end