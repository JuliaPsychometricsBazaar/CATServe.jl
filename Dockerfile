FROM --platform=linux/amd64 julia:1.9-bookworm

ENV JULIA_CPU_TARGET generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)

RUN mkdir /app
COPY . /app
WORKDIR /app

EXPOSE 8001

RUN julia -e "using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.precompile(); "
RUN julia --project=. setup_rcondapkg.jl

CMD ["/app/bin/server"]
