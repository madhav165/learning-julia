FROM julia

RUN julia -e 'using Pkg; Pkg.add("HTTP")'
RUN julia -e 'using Pkg; Pkg.add("JSON")'
RUN julia -e 'using Pkg; Pkg.add("LibPQ")'
RUN julia -e 'using Pkg; Pkg.add("Tables")'
RUN julia -e 'using Pkg; Pkg.add("Dates")'
RUN julia -e 'using Pkg; Pkg.add("DataFrames")'
RUN julia -e 'using Pkg; Pkg.add("Plots")'


COPY soc_bot.jl /home/
COPY psql_backend.jl /home/
COPY telegram.jl /home/
WORKDIR /home/

ENTRYPOINT julia soc_bot.jl