# adapted from http://distrustsimplicity.net/articles/mandelbrot-speed-comparison
# on linux use nproc to get number of cores
# run julia -p 4 mandelbrot.jl
# tested on julia ver 0.4.7

using Images

# multicore
@everywhere begin

function grayvalue(n)
    round(UInt8, clamp(n, 0, typemax(UInt8)))
end
    
function mandelbrotorbit(f, seed, bound, bailout=100, itmap=(n,zn,b)->n)
    z = f(seed)
    #z = seed^2 + c
    for k = 1:bailout
        if abs(z) > bound
            return itmap(k, z, bailout)
        end
        #z = z^2 + c
        z = f(z)
    end
    
    return -Inf
end

import Base.linspace

function linspace(start::Complex, finish::Complex, n::Integer, m::Integer)
    realParts = linspace(real(start), real(finish), n)
    complexParts = [Complex(0, b) for b=linspace(imag(start), imag(finish), m)]
    [ a + b for a=realParts, b=complexParts ]
end

normalized_iterations(n, zn, bailout) = n + (log(log(bailout))-log(log(abs(zn))))/(log(2))

function mandelbrot(points::SharedArray{Complex128,2}, colors::SharedArray{UInt8,2})
    const BAILOUT = 200

    f(c) = mandelbrotorbit(z -> z^2 + c, 0.0im, 2.0, BAILOUT, normalized_iterations)

    @sync @parallel for j=1:size(points,2)
        for k=1:size(points,1)
            @inbounds colors[k,j] = grayvalue(f(points[k,j]))
        end
    end
end



end


width=1011
# prepare input data
# points = convert(SharedArray, linspace(-2.5-1.25im, 1.0+1.25im, 3500, 2500))

print("points1:")
@time points = convert(SharedArray, linspace(-2-1.25im, 1.0+1.2im, width, width))
print("points2:")
@time points2 = convert(SharedArray, linspace(-2-1.25im, 1.0+1.2im, width, width))

# prepare results array
print("colors:")
colors = SharedArray(UInt8, size(points))
colors2 = SharedArray(UInt8, size(points2))

function mandelbrot_ser(points::SharedArray{Complex128,2}, colors::SharedArray{UInt8,2})
    const BAILOUT = 200

    f(c) = mandelbrotorbit(z -> z^2 + c, 0.0im, 2.0, BAILOUT, normalized_iterations)

    for j=1:size(points,2)
        for k=1:size(points,1)
            colors[k,j] = grayvalue(f(points[k,j]))
        end
    end
end



# compare execution time parallel, serial
print("par:")
@time mandelbrot(points, colors) 

print("ser:")
@time mandelbrot_ser(points2, colors2) 

image = grayim(sdata(colors))

save( "mandelbrot_gray_"*string(width)*".png",image);
