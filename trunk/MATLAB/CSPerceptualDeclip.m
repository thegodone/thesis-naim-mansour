function [x,r] = CSPerceptualDeclip(data, maskingThreshold)
%CSDECLIP - data is already clipped signal
%Naim Mansour
global methodChoice
%global A
%global samples
global regularization
addpath('ISD_v1.1')

[rs cs]=size(data);
if(rs~=1)
    data=data';
end
[rs2 cs2]=size(data);
N=cs2;

M=[];
Mn=[];
Mp=[];
samples=[];
MaxS=max(data);
MinS=min(data);
%Make sure the Base decomposes the samples as part of the signal, not as
%the signal itself!
for t=1:cs2 %border values possibly added to the clipped values - SOLVED
    if(data(1,t)<MaxS && data(1,t)>MinS)
        samples=[samples data(1,t)];
    elseif(((t==1 && data(1,t+1)-data(1,t)==0)  || (t==cs2 && data(1,t)-data(1,t-1)==0))... 
            || ((t~=1 && t~=cs2) && data(1,t-1)-data(1,t+1))==0)
        M=[M t];
        samples=[samples 0];
        if data(1,t)==MaxS
            Mp=[Mp t];
        else
            Mn=[Mn t];
        end
    else
        samples=[samples data(1,t)];
    end
end
samples=samples';
%Remove all rows in the DCT base, according to the sampling matrix!
% A=DCTBase(N,N,-1);
A=dctmtx(N)';
B=A;
A(M,:)=0; 

if length(A)==0
    disp('Clipping length exceeds frame length')
    return;
end

%Calculate filtermatrix
threshold = resample(maskingThreshold, length(A), length(maskingThreshold), 0);
W = perceptualWeightingMatrix(threshold);
A = A*W;

bla = samples' * W;
samples = bla';

Mpos=zeros(N,1);
Mpos(Mp,:)=1;
Mneg=zeros(N,1);
Mneg(Mn,:)=1;
MclA=diag(Mneg-Mpos)*B;
eps=0.9;
offSet=max(abs(samples))*eps;
% pause
%INHERENT PROBLEM, size of A needs to be consistent, not possible with only
%samples available - YES already solved (introducing don't care zeros)
%....

if regularization == []
    regularization=0.01;
end

%Solve the constrained L1 optimization (with lambda regularization)
methodChoice = 3;
switch methodChoice
    case 1
        x=SolveOMP(A,samples,N,50); %--FAST FAVORITE SO FAR
    case 2
        x=OMPDeclip(A,samples,N,MclA,50); %--FAST FAVORITE SO FAR
    case 3 
        x=SolveBP(A,samples,N,50,regularization,1e-4); %Investigate parameter impact
%         options = optimset('Algorithm','interior-point','Display','on');
%         [x, fval]=fmincon(@L1Norm,offSet*ones(N,1),MclA,offSet*ones(length(MclA),1),[],[],[],[],@L2Norm,options);
    case 4
        x=IRL1(A,samples,N,50,0.007,1e-3); %Development in progress
%           x=Threshold_ISD_1D(A,samples);
    case 5
        %x=SolveLasso(A,samples,N); %--VERY SLOW, NOT THAT ACCURATE
        options = struct('Verbose',0);
          [x,niter,residuals,outputData,opts] =NESTA(A,[],samples,0.01,1e-4,options);
end

% x=l1qc_logbarrier(pinv(A)*y,A,[],y,1);

r=idct(x);

subplot(5,1,1);plot(data);
title('Clipped signal')
axis([0 N (min(data)-1) (max(data)+1)])
subplot(5,1,2);plot(r(1:N,1));
title('Reconstructed signal')
axis([0 N (min(r)-1) (max(r)+1)])
% subplot(5,1,3);plot(orig)
% title('Original signal')
% axis([0 N (min(orig)-1) (max(orig)+1)])
subplot(5,1,4);plot(samples)
title('Samples')
axis([0 N (min(samples)-1) (max(samples)+1)])
subplot(5,1,5);plot(abs(x))
title('Spectral representation of reconstruction')
axis([0 N (min(abs(x))-1) (max(abs(x))+1)])
end
