function html_resp(s)
    io = IOBuffer()
    show(io, "text/html", s)
    Oxygen.html(String(take!(io)))
end

function html_ws(s)
    io = IOBuffer()
    show(io, "text/html", s)
    String(take!(io))
end