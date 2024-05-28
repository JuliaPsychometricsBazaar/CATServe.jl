function html_resp(s)
    io = IOBuffer()
    show(io, "text/html", s)
    Oxygen.html(String(take!(io)))
end