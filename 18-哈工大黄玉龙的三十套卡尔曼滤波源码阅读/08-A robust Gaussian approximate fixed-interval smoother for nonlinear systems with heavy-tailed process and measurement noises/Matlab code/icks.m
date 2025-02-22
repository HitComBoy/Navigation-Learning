function [xkNA,PkNA]=icks(xi,Pi,F,zA,ts,c0,d0,t0,T0,a0,b0,u0,U0,N)

%%%%Preparation
nx=size(xi,1);
nz=size(zA,1);

%%%%Initialization
%%%%%Process model
E_chi=ones(1,ts);
E_vw=c0/d0;
E_IQ=(t0-nx-1)*inv(T0);
%%%%%Measurement model
E_lamda=ones(1,ts);
E_ve=a0/b0;
E_IR=(u0-nz-1)*inv(U0);

%%%%%
ti=t0+ts;
ui=u0+ts;
ci=c0+0.5*ts;
ai=a0+0.5*ts;

for i=1:N

    %%%%Initial value for filter
    xkk=xi;
    Pkk=Pi;
    %%%%Save data for filter
    xkkA=xkk;
    PkkA=Pkk;
    xkk_1A=[];
    Pkk_1A=[];
    Pk_1kk_1A=[];
    
    for t=1:ts

        %%%%%Calculate Q and R
        Q=inv(E_IQ)/E_chi(t);
        R=inv(E_IR)/E_lamda(t);
        
        %%%%%%Filtering
        [xkk,Pkk,xkk_1,Pkk_1,Pk_1kk_1]=ckf(xkk,Pkk,F,zA(:,t),Q,R);   
        
        %%%%Save data for filter
        xkkA=[xkkA xkk];
        PkkA=[PkkA Pkk];
        xkk_1A=[xkk_1A xkk_1];
        Pkk_1A=[Pkk_1A Pkk_1];
        Pk_1kk_1A=[Pk_1kk_1A Pk_1kk_1];

    end
    
    %%%%Initial value for smoother
    xkN=xkk;
    PkN=Pkk;
    
    %%%%Save data for smoother
    xkNA=xkN;
    PkNA=PkN;
    KsA=[];  

    for t=(ts-1):-1:0
        
        %%%%%%Extracte filtering estimate
        xkk=xkkA(:,t+1);
        Pkk=PkkA(:,t*nx+1:(t+1)*nx);
        xkk_1=xkk_1A(:,t+1);
        Pkk_1=Pkk_1A(:,t*nx+1:(t+1)*nx);
        Pk_1kk_1=Pk_1kk_1A(:,t*nx+1:(t+1)*nx);
        
        %%%%%Calculate Q
        Q=inv(E_IQ)/E_chi(t+1);
        
        %%%%%%Smoothing
        [xkN,PkN,Ks]=cks(xkN,PkN,xkk,Pkk,xkk_1,Pkk_1,Pk_1kk_1);

        %%%%Save data for smoother
        xkNA=[xkN xkNA];
        PkNA=[PkN PkNA];
        KsA=[Ks KsA];

    end
    
    %%%%Update parameters
    Ti=T0;
    Ui=U0;
    di=d0-0.5*ts;
    bi=b0-0.5*ts;

    for t=1:ts
        
        %%%%%%%%%%%Extracte required parameters
        Gk_1=KsA(:,(t-1)*nx+1:t*nx);
        Pk_1N=PkNA(:,(t-1)*nx+1:t*nx);
        PkN=PkNA(:,t*nx+1:(t+1)*nx);
        xk_1N=xkNA(:,t);
        xkN=xkNA(:,t+1);
        z=zA(:,t);

        %%%%%%%%%%%Calculate auxiliary parameters
        Pk_1kN=Gk_1*PkN;
        
        %%%%%%%%%%%
        F_Q=PkN-(F*Pk_1kN)'-F*Pk_1kN+F*Pk_1N*F'+(xkN-F*xk_1N)*(xkN-F*xk_1N)';
        XkN=CR(xkN,PkN);
        F_R=(repmat(z,1,2*nx)-ckf_Mst(XkN))*(repmat(z,1,2*nx)-ckf_Mst(XkN))'/(2*nx);

        %%%%%%%%%%%Update the distribution parameters for \xi
        eta_kk=0.5*(nx+E_vw);
        theta_kk=0.5*(E_vw+trace(F_Q*E_IQ));
        
        %%%%%%%%%%%Update the distribution parameters for \lambda
        alfa_kk=0.5*(nz+E_ve);
        beta_kk=0.5*(E_ve+trace(F_R*E_IR));
        
        %%%%%%%%%%%Calculate E_\xi and E_\lambda
        E_chi(t)=eta_kk/theta_kk;
        E_lamda(t)=alfa_kk/beta_kk;
        
        %%%%%%%%%%Ti,Ui,di,bi
        Ti=Ti+E_chi(t)*F_Q;
        Ui=Ui+E_lamda(t)*F_R;
        di=di+0.5*E_chi(t)-0.5*(psi(eta_kk)-log(theta_kk));
        bi=bi+0.5*E_lamda(t)-0.5*(psi(alfa_kk)-log(beta_kk));
        
    end

    %%%%%%%%%%%%Calcualte expectations
    E_vw=ci/di;
    E_IQ=(ti-nx-1)*inv(Ti);
    E_ve=ai/bi;
    E_IR=(ui-nz-1)*inv(Ui);

end


