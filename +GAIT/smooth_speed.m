function sp = smooth_speed(x,y,n) 
% detect smooth speed
% x,y: coordinate of the point
% n: range of smooth. n>=1

if size(x) ~= size(y)
    error('x and y size mismatch.')
end

sp = sqrt((circshift(x,-n)-x).^2+(circshift(y,-n)-y).^2)./n;
sp(end-n:end) = 0;
sp = circshift(sp, round(n/2));

if n>1
    sp = shared.fastsmooth(sp, n);
end
