type Soft <: Layer; y; Soft()=new(); end

# Soft treats its input y as unnormalized log probabilities and
# applies the softmax function to overwrite it with normalized
# probabilities.  The normalization is across the last dimension:
# i.e. sum(y[:,...,:,i])==1 at the output. 
# (CUDNN_SOFTMAX_MODE_INSTANCE)


function forw(l::Soft,y; o...)
    nd = ndims(y)
    sz = size(y, nd)
    st = stride(y, nd)
    for j=1:sz
        i1=(j-1)*st+1
        i2=j*st
        ymax = typemin(eltype(y))
        ysum = zero(eltype(y))
        for i=i1:i2; y[i] > ymax && (ymax = y[i]); end
        for i=i1:i2; ysum += (y[i]=exp(y[i] - ymax)); end
        for i=i1:i2; y[i] /= ysum; end
    end
    return (l.y=y)
end

function back(l::Soft,dy; dx=true, o...)
    @assert size(dy)==size(l.y)
    dx || return
    nd = ndims(dy)
    sz = size(dy, nd)
    st = stride(dy, nd)
    for j=1:sz
        i1=(j-1)*st+1
        i2=j*st
        sumydy = zero(eltype(dy))
        for i=i1:i2; sumydy += l.y[i] * dy[i]; end
        for i=i1:i2; dy[i] = l.y[i] * (dy[i] - sumydy); end
    end
    return dy
end

if GPU
# TODO: what happened to the buggy 0.5 factor?
forw(l::Soft,y::CudaArray; o...)=(l.y=cudnnSoftmaxForward(y))
back(l::Soft,dy::CudaArray; dx=true, o...)=(dx && cudnnSoftmaxBackward(l.y, dy))
end # if GPU

