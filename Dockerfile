FROM --platform=linux/amd64 julia:1.9-bookworm

ENV JULIA_CPU_TARGET generic;sandybridge,-xsaveopt,clone_all;haswell,-rdrnd,base(1)
ENV JULIA_DEPOT_PATH /julia

RUN apt-get update && apt-get install libgl1-mesa-glx -y && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN mkdir /app
COPY \
	Manifest.toml \
	Project.toml \
	preprocess_item_banks.jl \
	run.jl \
	setup_rcondapkg.jl \
	/app/
COPY bin/ /app/bin/
COPY src/ /app/src/
WORKDIR /app

EXPOSE 8001

RUN julia -e "using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.precompile(); "
RUN julia --project=. setup_rcondapkg.jl
RUN julia -e "using Pkg; Pkg.activate(\".\"); Pkg.instantiate(); Pkg.precompile(); "
RUN julia --project=. preprocess_item_banks.jl

# Set group permissions equal to user so OpenShift can use its root group
# membership to write when needed
RUN chmod -R g=u /julia /app

CMD ["/app/bin/server"]
