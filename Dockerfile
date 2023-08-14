FROM --platform=linux/amd64 julia:1.9-bookworm

ENV JULIA_CPU_TARGET generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)

RUN mkdir /app
COPY \
	Manifest.toml \
	Project.toml \
	bin/ \
	preprocess_item_banks.jl \
	run.jl \
	setup_rcondapkg.jl \
	src/ \
	compiled/ \
	/app/
WORKDIR /app

EXPOSE 8001

RUN julia -e "using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.precompile(); "
RUN julia --project=. setup_rcondapkg.jl

CMD ["/app/bin/server"]
