FROM julia:1.9-bookworm

COPY compiled/sysimg.so /usr/local/lib/julia/sys.so
COPY run.jl /run.jl

CMD ["julia", "/run.jl"]
