function preview(data,t, datarange)

if nargin < 3
    datarange = [1:100000];
end
figure;
plot(t(datarange), data(datarange,:)+[1:size(data,2)]*1000);