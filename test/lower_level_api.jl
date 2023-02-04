using DiffEqGPU, StaticArrays, DiffEqBase, BenchmarkTools

trajectories = 10_000

const GROUP = get(ENV, "GROUP", "All")

function lorenz(u, p, t)
    σ = p[1]
    ρ = p[2]
    β = p[3]
    du1 = σ * (u[2] - u[1])
    du2 = u[1] * (ρ - u[3]) - u[2]
    du3 = u[1] * u[2] - β * u[3]
    return SVector{3}(du1, du2, du3)
end

u0 = @SVector [1.0f0; 0.0f0; 0.0f0]
tspan = (0.0f0, 10.0f0)
p = @SVector [10.0f0, 28.0f0, 8 / 3.0f0]
prob = ODEProblem{false}(lorenz, u0, tspan, p)

## Building different problems for different parameters
probs = map(1:trajectories) do i
    prob
end;

## Move the arrays to the GPU
@show GROUP == "ROCM"
if GROUP == "ROCM"
    @show "Here"
    using AMDGPU
    probs = roc(probs);
elseif GROUP == "ONEAPI"
    using oneAPI
    probs = probs |> oneArray
end
## Finally use the lower API for faster solves! (Fixed time-stepping)

# Run once for compilation
@time ts, us = DiffEqGPU.vectorized_solve(probs, prob, GPUTsit5(); save_everystep = false,
                                          dt = 0.1f0)

@time ts, us = DiffEqGPU.vectorized_solve(probs, prob, GPUTsit5(); save_everystep = false,
                                          dt = 0.1f0)

bench = @benchmark DiffEqGPU.vectorized_solve($probs, $prob, GPUTsit5();
                                              save_everystep = false,
                                              dt = 0.1f0)
@show bench
## Adaptive time-stepping
# Run once for compilation
@time ts, us = DiffEqGPU.vectorized_asolve(probs, prob, GPUTsit5(); save_everystep = false,
                                           dt = 0.1f0)

@time ts, us = DiffEqGPU.vectorized_asolve(probs, prob, GPUTsit5(); save_everystep = false,
                                           dt = 0.1f0)

bench = @benchmark DiffEqGPU.vectorized_asolve($probs, $prob, GPUTsit5();
                                               save_everystep = false,
                                               dt = 0.1f0)
@show bench
