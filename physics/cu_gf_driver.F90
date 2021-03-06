!
module cu_gf_driver

   ! DH* TODO: replace constants with arguments to cu_gf_driver_run
   use physcons  , g => con_g, cp => con_cp, xlv => con_hvap, r_v => con_rv
   use machine   , only: kind_phys
   use cu_gf_deep, only: cu_gf_deep_run,neg_check,autoconv,aeroevap
   use cu_gf_sh  , only: cu_gf_sh_run

   implicit none

   private

   public :: cu_gf_driver_init, cu_gf_driver_run, cu_gf_driver_finalize

contains

!> \brief Brief description of the subroutine
!!
!! \section arg_table_cu_gf_driver_init Argument Table
!! | local_name           | standard_name      | long_name                                | units | rank | type      |    kind   | intent | optional |
!! |----------------------|--------------------|------------------------------------------|-------|------|-----------|-----------|--------|----------|
!! | mpirank              | mpi_rank           | current MPI-rank                         | index |    0 | integer   |           | in     | F        |
!! | mpiroot              | mpi_root           | master MPI-rank                          | index |    0 | integer   |           | in     | F        |
!! | errmsg               | ccpp_error_message | error message for error handling in CCPP | none  |    0 | character | len=*     | out    | F        |
!! | errflg               | ccpp_error_flag    | error flag for error handling in CCPP    | flag  |    0 | integer   |           | out    | F        |
!!
      subroutine cu_gf_driver_init(mpirank, mpiroot, errmsg, errflg)

         implicit none

         integer,                   intent(in)    :: mpirank
         integer,                   intent(in)    :: mpiroot
         character(len=*),          intent(  out) :: errmsg
         integer,                   intent(  out) :: errflg

         ! DH* temporary
         if (mpirank==mpiroot) then
            write(0,*) ' -----------------------------------------------------------------------------------------------------------------------------'
            write(0,*) ' --- WARNING --- the CCPP Grell Freitas convection scheme is currently under development, use at your own risk --- WARNING ---'
            write(0,*) ' -----------------------------------------------------------------------------------------------------------------------------'
         end if
         ! *DH temporary

      end subroutine cu_gf_driver_init


!> \brief Brief description of the subroutine
!!
!! \section arg_table_cu_gf_driver_finalize Argument Table
!!
      subroutine cu_gf_driver_finalize()
      end subroutine cu_gf_driver_finalize
!
! t2di is temp after advection, but before physics
! t = current temp (t2di + physics up to now)
!===================
!
!!
!! \section arg_table_cu_gf_driver_run Argument Table
!! | local_name     | standard_name                                             | long_name                                           | units         | rank | type      |    kind   | intent | optional |
!! |----------------|-----------------------------------------------------------|-----------------------------------------------------|---------------|------|-----------|-----------|--------|----------|
!! | tottracer      | number_of_total_tracers                                   | number of total tracers                             | count         |    0 | integer   |           | in     | F        |
!! | ntrac          | number_of_vertical_diffusion_tracers                      | number of tracers to diffuse vertically             | count         |    0 | integer   |           | in     | F        |
!! | garea          | cell_area                                                 | grid cell area                                      | m2            |    1 | real      | kind_phys | in     | F        |
!! | im             | horizontal_loop_extent                                    | horizontal loop extent                              | count         |    0 | integer   |           | in     | F        |
!! | ix             | horizontal_dimension                                      | horizontal dimension                                | count         |    0 | integer   |           | in     | F        |
!! | km             | vertical_dimension                                        | vertical layer dimension                            | count         |    0 | integer   |           | in     | F        |
!! | dt             | time_step_for_physics                                     | physics time step                                   | s             |    0 | real      | kind_phys | in     | F        |
!! | cactiv         | conv_activity_counter                                     | convective activity memory                          | none          |    1 | integer   |           | inout  | F        |
!! | forcet         | temperature_tendency_due_to_dynamics                      | temperature tendency due to dynamics only           | K s-1         |    2 | real      | kind_phys | in     | F        |
!! | forceq         | moisture_tendency_due_to_dynamics                         | moisture tendency due to dynamics only              | kg kg-1 s-1   |    2 | real      | kind_phys | in     | F        |
!! | phil           | geopotential                                              | layer geopotential                                  | m2 s-2        |    2 | real      | kind_phys | in     | F        |
!! | raincv         | lwe_thickness_of_deep_convective_precipitation_amount     | deep convective rainfall amount on physics timestep | m             |    1 | real      | kind_phys | out    | F        |
!! | q              | tracer_concentration_updated_by_physics                   | tracer concentration updated by physics             | kg kg-1       |    3 | real      | kind_phys | inout  | F        |
!! | t              | air_temperature_updated_by_physics                        | updated temperature                                 | K             |    2 | real      | kind_phys | inout  | F        |
!! | cld1d          | cloud_work_function                                       | cloud work function                                 | m2 s-2        |    1 | real      | kind_phys | out    | F        |
!! | us             | x_wind_updated_by_physics                                 | updated x-direction wind                            | m s-1         |    2 | real      | kind_phys | inout  | F        |
!! | vs             | y_wind_updated_by_physics                                 | updated y-direction wind                            | m s-1         |    2 | real      | kind_phys | inout  | F        |
!! | t2di           | air_temperature                                           | mid-layer temperature                               | K             |    2 | real      | kind_phys | in     | F        |
!! | w              | omega                                                     | layer mean vertical velocity                        | Pa s-1        |    2 | real      | kind_phys | in     | F        |
!! | q2di           | tracer_concentration                                      | water vapor specific humidity                       | kg kg-1       |    3 | real      | kind_phys | in     | F        |
!! | p2di           | air_pressure                                              | mean layer pressure                                 | Pa            |    2 | real      | kind_phys | in     | F        |
!! | psuri          | surface_air_pressure                                      | surface pressure                                    | Pa            |    1 | real      | kind_phys | in     | F        |
!! | hbot           | vertical_index_at_cloud_base                              | index for cloud base                                | index         |    1 | integer   |           | out    | F        |
!! | htop           | vertical_index_at_cloud_top                               | index for cloud top                                 | index         |    1 | integer   |           | out    | F        |
!! | kcnv           | flag_deep_convection                                      | deep convection: 0=no, 1=yes                        | flag          |    1 | integer   |           | out    | F        |
!! | xland          | sea_land_ice_mask                                         | landmask: sea/land/ice=0/1/2                        | flag          |    1 | integer   |           | in     | F        |
!! | hfx2           | kinematic_surface_upward_sensible_heat_flux               | kinematic surface upward sensible heat flux         | K m s-1       |    1 | real      | kind_phys | in     | F        |
!! | qfx2           | kinematic_surface_upward_latent_heat_flux                 | kinematic surface upward latent heat flux           | kg kg-1 m s-1 |    1 | real      | kind_phys | in     | F        |
!! | clw            | convective_transportable_tracers                          | cloud water and other convective trans. tracers     | kg kg-1       |    3 | real      | kind_phys | inout  | F        |
!! | pbl            | atmosphere_boundary_layer_thickness                       | PBL thickness                                       | m             |    1 | real      | kind_phys | in     | F        |
!! | ud_mf          | instantaneous_atmosphere_updraft_convective_mass_flux     | (updraft mass flux) * delt                          | kg m-2        |    2 | real      | kind_phys | out    | F        |
!! | dd_mf          | instantaneous_atmosphere_downdraft_convective_mass_flux   | (downdraft mass flux) * delt                        | kg m-2        |    2 | real      | kind_phys | out    | F        |
!! | dt_mf          | instantaneous_atmosphere_detrainment_convective_mass_flux | (detrainment mass flux) * delt                      | kg m-2        |    2 | real      | kind_phys | out    | F        |
!! | cnvw           | convective_cloud_water_mixing_ratio                       | convective cloud water                              | kg kg-1       |    2 | real      | kind_phys | out    | F        |
!! | cnvc           | convective_cloud_cover                                    | convective cloud cover                              | frac          |    2 | real      | kind_phys | out    | F        |
!! | errmsg         | ccpp_error_message                                        | error message for error handling in CCPP            | none          |    0 | character | len=*     | out    | F        |
!! | errflg         | ccpp_error_flag                                           | error flag for error handling in CCPP               | flag          |    0 | integer   |           | out    | F        |
!!
      subroutine cu_gf_driver_run(tottracer,ntrac,garea,im,ix,km,dt,cactiv, &
               forcet,forceq,phil,raincv,q,t,cld1d,       &
               us,vs,t2di,w,q2di,p2di,psuri,              &
               hbot,htop,kcnv,xland,hfx2,qfx2,clw,          &
               pbl,ud_mf,dd_mf,dt_mf,cnvw,cnvc,errmsg,errflg)
!              pbl,ud_mf,dd_mf,dt_mf,gdc,gdc2,cnvw,cnvc,ishal_cnv)
!-------------------------------------------------------------
      implicit none
      integer, parameter :: maxiens=1
      integer, parameter :: maxens=1
      integer, parameter :: maxens2=1
      integer, parameter :: maxens3=16
      integer, parameter :: ensdim=16
      integer, parameter :: ishal_cnv=3
      integer            :: ishallow_g3=1 ! depend on ishal_cnv
      integer, parameter :: imid_gf=1    ! testgf2 turn on middle gf conv.
      integer, parameter :: ideep=1
      integer, parameter :: ichoice=0	! 0 2 5 13 8
      integer, parameter :: ichoicem=5	! 0 2 5 13
      integer, parameter :: ichoice_s=3	! 0 1 2 3
      real(kind=kind_phys), parameter :: aodccn=0.1
      real(kind=kind_phys) :: dts,fpi,fp
      integer, parameter :: dicycle=0 ! diurnal cycle flag
      integer, parameter :: dicycle_m=0 !- diurnal cycle flag
!-------------------------------------------------------------
   integer      :: its,ite, jts,jte, kts,kte 
   integer, intent(in   ) :: im,ix,km,ntrac,tottracer

   real(kind=kind_phys),  dimension( ix , km ),     intent(in ) :: forcet,forceq,w,phil
   real(kind=kind_phys),  dimension( ix , km ),     intent(inout ) :: t,us,vs
   real(kind=kind_phys),  dimension( ix )   :: rand_mom,rand_vmas
   real(kind=kind_phys),  dimension( ix,4 ) :: rand_clos
   real(kind=kind_phys),  dimension( ix , km, 11 ) :: gdc,gdc2
   real(kind=kind_phys),  dimension( ix , km ),     intent(inout ) :: cnvw,cnvc
   real(kind=kind_phys),  dimension( ix , km,tottracer+2 ), intent(inout ) :: clw

!hj change from ix to im
   integer, dimension (im), intent(inout) :: hbot,htop,kcnv
   integer,    dimension (im), intent(in) :: xland
   real(kind=kind_phys),    dimension (im), intent(in) :: pbl
   integer, dimension (ix) :: tropics
! ruc variable
   real(kind=kind_phys), dimension (im)  :: hfx2,qfx2,psuri
   real(kind=kind_phys), dimension (im,km) :: ud_mf,dd_mf,dt_mf
   real(kind=kind_phys), dimension (im), intent(inout) :: raincv,cld1d
!hj end change ix to im
   real(kind=kind_phys), dimension (ix,km) :: t2di,p2di
   real(kind=kind_phys), dimension (ix,km,ntrac) :: q2di,q
   real(kind=kind_phys), dimension( im ),intent(in) :: garea
   real(kind=kind_phys), intent(in   ) :: dt 
!  integer, intent(in   ) :: ishal_cnv
   character(len=*), intent(out) :: errmsg
   integer,          intent(out) :: errflg
!hj define locally for now.
   integer, dimension(im),intent(inout) :: cactiv ! hli for gf
!hj change from ix to im
   integer, dimension(im) :: k22_shallow,kbcon_shallow,ktop_shallow
   real(kind=kind_phys),    dimension(im) :: ht
!hj change
!
!+lxz
!hj  real(kind=kind_phys) :: dx
   real(kind=kind_phys),    dimension(im) :: dx
! local vars
!hj change ix to im
     real(kind=kind_phys), dimension (im,km) :: outt,outq,outqc,phh,subm,cupclw,cupclws
     real(kind=kind_phys), dimension (im,km) :: dhdt,zu,zus,zd,phf,zum,zdm,outum,outvm
     real(kind=kind_phys), dimension (im,km) :: outts,outqs,outqcs,outu,outv,outus,outvs
     real(kind=kind_phys), dimension (im,km) :: outtm,outqm,outqcm,submm,cupclwm
     real(kind=kind_phys), dimension (im,km) :: cnvwt,cnvwts,cnvwtm
     real(kind=kind_phys), dimension (im,km) :: hco,hcdo,zdo,zdd,hcom,hcdom,zdom
     real(kind=kind_phys), dimension    (km) :: zh
     real(kind=kind_phys), dimension (im)    :: tau_ecmwf,edt,edtm,edtd,ter11,aa0,xlandi
     real(kind=kind_phys), dimension (im)    :: pret,prets,pretm,hexec
     real(kind=kind_phys), dimension (im,10) :: forcing,forcing2
!+lxz
     integer, dimension (im) :: kbcon, ktop,ierr,ierrs,ierrm,kpbli
     integer, dimension (im) :: k22s,kbcons,ktops,k22,jmin,jminm
     integer, dimension (im) :: kbconm,ktopm,k22m
!hj end change ix to im
!.lxz
     integer :: iens,ibeg,iend,jbeg,jend,n
     integer :: ibegh,iendh,jbegh,jendh
     integer :: ibegc,iendc,jbegc,jendc,kstop
     real(kind=kind_phys) :: rho_dryar,temp
     real(kind=kind_phys) :: pten,pqen,paph,zrho,pahfs,pqhfl,zkhvfl,pgeoh
!hj 10/11/2016: ipn is an input in fim. set it to zero here.
     integer, parameter :: ipn = 0

!
! basic environmental input includes moisture convergence (mconv)
! omega (omeg), windspeed (us,vs), and a flag (ierr) to turn off
! convection for this call only and at that particular gridpoint
!
!hj 10/11/2016: change ix to im.
     real(kind=kind_phys), dimension (im,km) :: qcheck,zo,t2d,q2d,po,p2d,rhoi
     real(kind=kind_phys), dimension (im,km) :: tn,qo,tshall,qshall,dz8w,omeg
     real(kind=kind_phys), dimension (im)    :: ccn,z1,psur,cuten,cutens,cutenm
     real(kind=kind_phys), dimension (im)    :: umean,vmean,pmean
     real(kind=kind_phys), dimension (im)    :: xmbs,xmbs2,xmb,xmbm,xmb_dumm,mconv
!hj end change ix to im

     integer :: i,j,k,icldck,ipr,jpr,jpr_deep,ipr_deep
     integer :: itf,jtf,ktf,iss,jss,nbegin,nend
     integer :: high_resolution
     real(kind=kind_phys)    :: clwtot,clwtot1,excess,tcrit,tscl_kf,dp,dq,sub_spread,subcenter
     real(kind=kind_phys)    :: dsubclw,dsubclws,dsubclwm,ztm,ztq,hfm,qfm,rkbcon,rktop        !-lxz
!hj change ix to im
     real(kind=kind_phys), dimension (im)  :: flux_tun,tun_rad_mid,tun_rad_shall,tun_rad_deep
     character*50 :: ierrc(im),ierrcm(im)
     character*50 :: ierrcs(im)
!hj end change ix to im
! ruc variable
!hj hfx2 -- sensible heat flux (k m/s), positive upward from sfc
!hj qfx2 -- latent heat flux (kg/kg m/s), positive upward from sfc 
!hj gf needs them in w/m2. define hfx and qfx after simple unit conversion
     real(kind=kind_phys), dimension (im)  :: hfx,qfx
     real(kind=kind_phys) tem,tem1,tf,tcr,tcrf

     parameter (tf=233.16, tcr=263.16, tcrf=1.0/(tcr-tf))
     !parameter (tf=258.16, tcr=273.16, tcrf=1.0/(tcr-tf)) ! as fim
     ! initialize ccpp error handling variables
     errmsg = ''
     errflg = 0
!
! these should be coming in from outside
!
!     print*,'hli in gf cactiv',cactiv
!     cactiv(:)      = 0
     rand_mom(:)    = 0.
     rand_vmas(:)   = 0.
     rand_clos(:,:) = 0.
     its=1
     ite=im
     jts=1
     jte=1
     kts=1
     kte=km
     ktf=kte-1
! 
     tropics(:)=0
!
!> tuning constants for radiation coupling
!
   tun_rad_shall(:)=.02
   tun_rad_mid(:)=.15
   tun_rad_deep(:)=.13
   edt(:)=0.
   edtm(:)=0.
   edtd(:)=0.
   zdd(:,:)=0.
   flux_tun(:)=5.
!hj 10/11/2016 dx and tscl_kf are replaced with input dx(i), is dlength. 
  ! dx for scale awareness
!hj   dx=40075000./float(lonf)
!hj   tscl_kf=dx/25000.
   ccn(its:ite)=150.
  !
   if (ishal_cnv == 2 .or. ishal_cnv == 3) ishallow_g3 = 1
   high_resolution=0
   subcenter=0.
   iens=1
!
! these can be set for debugging
!
   ipr=0
   jpr=0
   ipr_deep=0
   jpr_deep= 0 !53322 ! 528196 !0 ! 1136 !0 !421755 !3536
!
!
   ibeg=its
   iend=ite
   tcrit=258.

   itf=ite
   ktf=kte-1
   jtf=jte
   ztm=0.
   ztq=0.
   hfm=0.
   qfm=0.
   ud_mf =0.
   dd_mf =0.
   dt_mf =0.
   tau_ecmwf(:)=0.
!                                                                      
       j=1
       ht(:)=phil(:,1)/g
       do i=its,ite
        cld1d(i)=0.
        zo(i,:)=phil(i,:)/g
        dz8w(i,1)=zo(i,2)-zo(i,1)
        zh(1)=0.
        kpbli(i)=2
        do k=kts+1,ktf
          dz8w(i,k)=zo(i,k+1)-zo(i,k)
        enddo
        do k=kts+1,ktf
          zh(k)=zh(k-1)+dz8w(i,k-1)
          if(zh(k).gt.pbl(i))then
           kpbli(i)=max(2,k)
           exit
          endif
        enddo
       enddo
     do i= its,itf
        forcing(i,:)=0.
        forcing2(i,:)=0.
        ccn(i)=100.
        hbot(i)  =kte
        htop(i)  =kts
        raincv(i)=0.
        xlandi(i)=real(xland(i))
!       if(abs(xlandi(i)-1.).le.1.e-3) tun_rad_shall(i)=.15     
!       if(abs(xlandi(i)-1.).le.1.e-3) flux_tun(i)=1.5     
     enddo
     do i= its,itf
        mconv(i)=0.
     enddo
     do k=kts,kte
     do i= its,itf
         omeg(i,k)=0.
         zu(i,k)=0.
         zum(i,k)=0.
         zus(i,k)=0.
         zd(i,k)=0.
         zdm(i,k)=0.
     enddo
     enddo

     psur(:)=0.01*psuri(:)
     do i=its,itf
         ter11(i)=max(0.,ht(i))
     enddo
     do k=kts,kte
     do i=its,ite
         cnvw(i,k)=0.
         cnvc(i,k)=0.
         gdc(i,k,1)=0.
         gdc(i,k,2)=0.
         gdc(i,k,3)=0.
         gdc(i,k,4)=0.
         gdc(i,k,7)=0.
         gdc(i,k,8)=0.
         gdc(i,k,9)=0.
         gdc(i,k,10)=0.
         gdc2(i,k,1)=0.
     enddo
     enddo
     ierr(:)=0
     ierrm(:)=0
     ierrs(:)=0
     cuten(:)=0.
     cutenm(:)=0.
     cutens(:)=1.
     if(ishallow_g3.eq.0)cutens(:)=0.
     ierrc(:)=" "

     kbcon(:)=0
     kbcons(:)=0
     kbconm(:)=0

     ktop(:)=0
     ktops(:)=0
     ktopm(:)=0

     xmb(:)=0.
     xmb_dumm(:)=0.
     xmbm(:)=0.
     xmbs(:)=0.
     xmbs2(:)=0.

     k22s(:)=0
     k22m(:)=0
     k22(:)=0

     jmin(:)=0
     jminm(:)=0

     pret(:)=0.
     prets(:)=0.
     pretm(:)=0.

     umean(:)=0.
     vmean(:)=0.
     pmean(:)=0.

     cupclw(:,:)=0.
     cupclwm(:,:)=0.
     cupclws(:,:)=0.

     cnvwt(:,:)=0.
     cnvwts(:,:)=0.

     hco(:,:)=0.
     hcom(:,:)=0.
     hcdo(:,:)=0.
     hcdom(:,:)=0.

     outt(:,:)=0.
     outts(:,:)=0.
     outtm(:,:)=0.

     outu(:,:)=0.
     outus(:,:)=0.
     outum(:,:)=0.

     outv(:,:)=0.
     outvs(:,:)=0.
     outvm(:,:)=0.

     outq(:,:)=0.
     outqs(:,:)=0.
     outqm(:,:)=0.

     outqc(:,:)=0.
     outqcs(:,:)=0.
     outqcm(:,:)=0.

     subm(:,:)=0.
     dhdt(:,:)=0.
     !print*,'hli t2di',t2di
     !print*,'hli forcet',forcet
     
     do k=kts,ktf
     do i=its,itf
         p2d(i,k)=0.01*p2di(i,k)
         po(i,k)=p2d(i,k) !*.01
         rhoi(i,k) = 100.*p2d(i,k)/(287.04*(t2di(i,k)*(1.+0.608*q2di(i,k,1))))
         qcheck(i,k)=q(i,k,1)
         tn(i,k)=t(i,k)!+forcet(i,k)*dt
         qo(i,k)=max(1.e-16,q(i,k,1))!+forceq(i,k)*dt
         t2d(i,k)=t2di(i,k)-forcet(i,k)*dt
         !print*,'hli t2di(i,k),forcet(i,k),dt,t2d(i,k)',t2di(i,k),forcet(i,k),dt,t2d(i,k)
         q2d(i,k)=max(1.e-16,q2di(i,k,1)-forceq(i,k)*dt)
         if(qo(i,k).lt.1.e-16)qo(i,k)=1.e-16
         tshall(i,k)=t2d(i,k)
         qshall(i,k)=q2d(i,k)
!hj         if(ipn.eq.jpr_deep)then
!hj          write(12,123)k,dt,p2d(i,k),t2d(i,k),tn(i,k),q2d(i,k),qo(i,k),forcet(i,k)
!hj         endif
     enddo
     enddo
123  format(1x,i2,1x,2(1x,f8.0),1x,2(1x,f8.3),3(1x,e13.5))
     do i=its,itf
     do k=kts,kpbli(i)
         tshall(i,k)=t(i,k)
         qshall(i,k)=max(1.e-16,q(i,k,1))
     enddo
     enddo
!
!hj converting hfx2 and qfx2 to w/m2
!hj hfx=cp*rho*hfx2
!hj qfx=xlv*qfx2
     do i=its,itf
         hfx(i)=hfx2(i)*cp*rhoi(i,1)
         qfx(i)=qfx2(i)*xlv
         dx(i) = sqrt(garea(i))
         !print*,'hli dx', dx(i)
     enddo
!hj     write(0,*),'hfx',hfx(3),qfx(3),rhoi(3,1)
!hj
     do i=its,itf
     do k=kts,kpbli(i)
         tn(i,k)=t(i,k) 
         qo(i,k)=max(1.e-16,q(i,k,1))
     enddo
     enddo
     nbegin=0
     nend=0
         do i=its,itf
         do k=kts,kpbli(i)
         dhdt(i,k)=cp*(forcet(i,k)+(t(i,k)-t2di(i,k))/dt) +  & 
                   xlv*(forceq(i,k)+(q(i,k,1)-q2di(i,k,1))/dt) 
!         tshall(i,k)=t(i,k) 
!         qshall(i,k)=q(i,k,1) 
        enddo
        enddo
      do k=  kts+1,ktf-1
      do i = its,itf
         if((p2d(i,1)-p2d(i,k)).gt.150.and.p2d(i,k).gt.300)then
            dp=-.5*(p2d(i,k+1)-p2d(i,k-1))
            umean(i)=umean(i)+us(i,k)*dp
            vmean(i)=vmean(i)+vs(i,k)*dp
            pmean(i)=pmean(i)+dp
         endif
      enddo
      enddo
      do k=kts,ktf-1
      do i = its,itf
        omeg(i,k)= w(i,k) !-g*rhoi(i,k)*w(i,k)
!        dq=(q2d(i,k+1)-q2d(i,k))
!        mconv(i)=mconv(i)+omeg(i,k)*dq/g
      enddo
      enddo
      do i = its,itf
        if(mconv(i).lt.0.)mconv(i)=0.
      enddo
!
!---- call cumulus parameterization
!
       if(ishallow_g3.eq.1)then
!
          do i=its,ite
           ierrs(i)=0
           ierrm(i)=0
          enddo
!
!> if ishallow_g3=1, call shallow: cup_gf_sh()
!
    ! print*,'hli bf shallow t2d',t2d
          call cu_gf_sh_run (                                              &
! input variables, must be supplied
                         zo,t2d,q2d,ter11,tshall,qshall,p2d,psur,dhdt,kpbli,     &
                         rhoi,hfx,qfx,xlandi,ichoice_s,tcrit,dt, &
! input variables. ierr should be initialized to zero or larger than zero for
! turning off shallow convection for grid points
                         zus,xmbs,kbcons,ktops,k22s,ierrs,ierrcs,    &
! output tendencies
                         outts,outqs,outqcs,cnvwt,prets,cupclws,             &
! dimesnional variables
                         itf,ktf,its,ite, kts,kte,ipr,tropics)


          do i=its,itf
           if(xmbs(i).le.0.)cutens(i)=0.
          enddo
          call neg_check('shallow',ipn,dt,qcheck,outqs,outts,outus,outvs,   &
                                 outqcs,prets,its,ite,kts,kte,itf,ktf,ktops)
       endif

       ipr=0
       jpr_deep=0 !340765
!> if imid_gf=1, call cup_gf()
   if(imid_gf == 1)then
      call cu_gf_deep_run(        &
               itf,ktf,its,ite, kts,kte  &
              ,dicycle_m       &
              ,ichoicem       &
              ,ipr           &
              ,ccn           &
              ,dt            &
              ,imid_gf       &
              ,kpbli         &
              ,dhdt          &
              ,xlandi        &

              ,zo            &
              ,forcing2      &
              ,t2d           &
              ,q2d           &
              ,ter11         &
              ,tshall        &
              ,qshall        &
              ,p2d          &
              ,psur          &
              ,us            &
              ,vs            &
              ,rhoi          &
              ,hfx           &
              ,qfx           &
              ,dx            & !hj dx(im)
              ,mconv         &
              ,omeg          &

              ,cactiv        &
              ,cnvwtm        &
              ,zum           &
              ,zdm           & ! hli
              ,zdd           &
              ,edtm          &
              ,edtd          & ! hli
              ,xmbm          &
              ,xmb_dumm      &
              ,xmbs          &
              ,pretm         &
              ,outum         &
              ,outvm         &
              ,outtm         &
              ,outqm         &
              ,outqcm        &
              ,kbconm        &
              ,ktopm         &
              ,cupclwm       &
              ,ierrm         &
              ,ierrcm        &
!    the following should be set to zero if not available
              ,rand_mom      & ! for stochastics mom, if temporal and spatial patterns exist
              ,rand_vmas     & ! for stochastics vertmass, if temporal and spatial patterns exist
              ,rand_clos     & ! for stochastics closures, if temporal and spatial patterns exist
              ,0             & ! flag to what you want perturbed
                               ! 1 = momentum transport 
                               ! 2 = normalized vertical mass flux profile
                               ! 3 = closures
                               ! more is possible, talk to developer or
                               ! implement yourself. pattern is expected to be
                               ! betwee -1 and +1
#if ( wrf_dfi_radar == 1 )
              ,do_capsuppress,cap_suppress_j &
#endif
              ,k22m          &
              ,jminm,tropics)

            do i=its,itf
            do k=kts,ktf
              qcheck(i,k)=q(i,k,1) +outqs(i,k)*dt
            enddo
            enddo
      call neg_check('mid',ipn,dt,qcheck,outqm,outtm,outum,outvm,   &
                     outqcm,pretm,its,ite,kts,kte,itf,ktf,ktopm)
    endif
!> if ideep=1, call cup_gf()
   if(ideep.eq.1)then
      call cu_gf_deep_run(        &
               itf,ktf,its,ite, kts,kte  &

              ,dicycle       &
              ,ichoice       &
              ,ipr           &
              ,ccn           &
              ,dt            &
              ,0             &

              ,kpbli         &
              ,dhdt          &
              ,xlandi        &

              ,zo            &
              ,forcing       &
              ,t2d           &
              ,q2d           &
              ,ter11         &
              ,tn            &
              ,qo            &
              ,p2d           &
              ,psur          &
              ,us            &
              ,vs            &
              ,rhoi          &
              ,hfx           &
              ,qfx           &
              ,dx            & !hj replace dx(im)
              ,mconv         &
              ,omeg          &

              ,cactiv       &
              ,cnvwt        &
              ,zu           &
              ,zd           &
              ,zdm          & ! hli
              ,edt          &
              ,edtm         & ! hli
              ,xmb          &
              ,xmbm         &
              ,xmbs         &
              ,pret         &
              ,outu         &
              ,outv         &
              ,outt         &
              ,outq         &
              ,outqc        &
              ,kbcon        &
              ,ktop         &
              ,cupclw       &
              ,ierr         &
              ,ierrc        &
!    the following should be set to zero if not available
              ,rand_mom      & ! for stochastics mom, if temporal and spatial patterns exist
              ,rand_vmas     & ! for stochastics vertmass, if temporal and spatial patterns exist
              ,rand_clos     & ! for stochastics closures, if temporal and spatial patterns exist
              ,0             & ! flag to what you want perturbed
                               ! 1 = momentum transport 
                               ! 2 = normalized vertical mass flux profile
                               ! 3 = closures
                               ! more is possible, talk to developer or
                               ! implement yourself. pattern is expected to be
                               ! betwee -1 and +1
#if ( wrf_dfi_radar == 1 )
              ,do_capsuppress,cap_suppress_j &
#endif
              ,k22          &
              ,jmin,tropics)
        jpr=0
        ipr=0
            do i=its,itf
            do k=kts,ktf
              qcheck(i,k)=q(i,k,1) +(outqs(i,k)+outqm(i,k))*dt
            enddo
            enddo
      call neg_check('deep',ipn,dt,qcheck,outq,outt,outu,outv,   &
                      outqc,pret,its,ite,kts,kte,itf,ktf,ktop)
!
      endif
            do i=its,itf
              kcnv(i)=0  
              if(pret(i).gt.0.)then
                 cuten(i)=1.
                 kcnv(i)= 1 !jmin(i) 
              else 
                 kbcon(i)=0
                 ktop(i)=0
                 cuten(i)=0.
              endif   ! pret > 0
              if(pretm(i).gt.0.)then
                 kcnv(i)= 1 !jmin(i)  
                 cutenm(i)=1.
              else 
                 kbconm(i)=0
                 ktopm(i)=0
                 cutenm(i)=0.
              endif   ! pret > 0
            enddo
!
            do i=its,itf
            kstop=kts
            if(ktopm(i).gt.kts .or. ktop(i).gt.kts)kstop=max(ktopm(i),ktop(i))
            if(ktops(i).gt.kts)kstop=max(kstop,ktops(i))
            if(kstop.gt.2)then
            htop(i)=kstop
            if(kbcon(i).gt.2 .or. kbconm(i).gt.2)then
               hbot(i)=max(kbconm(i),kbcon(i)) !jmin(i)
            endif
!kbcon(i)
            do k=kts,kstop
               cnvc(i,k) = 0.04 * log(1. + 675. * zu(i,k) * xmb(i)) +   &
                           0.04 * log(1. + 675. * zum(i,k) * xmbm(i)) + &
                           0.04 * log(1. + 675. * zus(i,k) * xmbs(i))
               cnvc(i,k) = min(cnvc(i,k), 0.6)
               cnvc(i,k) = max(cnvc(i,k), 0.0)
               cnvw(i,k)=cnvwt(i,k)*xmb(i)*dt+cnvwts(i,k)*xmbs(i)*dt+cnvwtm(i,k)*xmbm(i)*dt
               ud_mf(i,k)=cuten(i)*zu(i,k)*xmb(i)*dt
               dd_mf(i,k)=cuten(i)*zd(i,k)*edt(i)*xmb(i)*dt
               t(i,k)=t(i,k)+dt*(cutens(i)*outts(i,k)+cutenm(i)*outtm(i,k)+outt(i,k)*cuten(i))
               q(i,k,1)=max(1.e-16,q(i,k,1)+dt*(cutens(i)*outqs(i,k)+cutenm(i)*outqm(i,k)+outq(i,k)*cuten(i)))
               gdc(i,k,7)=sqrt(us(i,k)**2 +vs(i,k)**2)
               us(i,k)=us(i,k)+outu(i,k)*cuten(i)*dt +outum(i,k)*cutenm(i)*dt
               vs(i,k)=vs(i,k)+outv(i,k)*cuten(i)*dt +outvm(i,k)*cutenm(i)*dt

!hj 10/11/2016: don't need gdc and gdc2 yet for gsm. 
!hli 08/18/2017: couple gdc to radiation
               gdc(i,k,1)= max(0.,tun_rad_shall(i)*cupclws(i,k)*cutens(i))	! my mod
               gdc2(i,k,1)=max(0.,tun_rad_deep(i)*(cupclwm(i,k)*cutenm(i)+cupclw(i,k)*cuten(i)))
               gdc(i,k,2)=(outt(i,k))*86400.
               gdc(i,k,3)=(outtm(i,k))*86400. 
               gdc(i,k,4)=(outts(i,k))*86400.
               gdc(i,k,7)=-(gdc(i,k,7)-sqrt(us(i,k)**2 +vs(i,k)**2))/dt
               !gdc(i,k,8)=(outq(i,k))*86400.*xlv/cp
               gdc(i,k,8)=(outqm(i,k)+outqs(i,k)+outq(i,k))*86400.*xlv/cp 
               gdc(i,k,9)=gdc(i,k,2)+gdc(i,k,3)+gdc(i,k,4)
               if((gdc(i,k,1).ge.0.5).or.(gdc2(i,k,1).ge.0.5))then
                print*,'hli gdc(i,k,1),gdc2(i,k,1)',gdc(i,k,1),gdc2(i,k,1)
               endif
!
!> calculate subsidence effect on clw
!
               dsubclw=0.
               dsubclwm=0.
               dsubclws=0.
               dp=100.*(p2d(i,k)-p2d(i,k+1))
               if (clw(i,k,2) .gt. -999.0 .and. clw(i,k+1,2) .gt. -999.0 )then
                  clwtot = clw(i,k,1) + clw(i,k,2)
                  clwtot1= clw(i,k+1,1) + clw(i,k+1,2)
                  dsubclw=((-edt(i)*zd(i,k+1)+zu(i,k+1))*clwtot1   &
                       -(-edt(i)*zd(i,k)  +zu(i,k))  *clwtot  )*g/dp
                  dsubclwm=((-edtm(i)*zdm(i,k+1)+zum(i,k+1))*clwtot1   &
                       -(-edtm(i)*zdm(i,k)  +zum(i,k))  *clwtot  )*g/dp
                  dsubclws=(zus(i,k+1)*clwtot1-zus(i,k)*clwtot)*g/dp
                  dsubclw=dsubclw+(zu(i,k+1)*clwtot1-zu(i,k)*clwtot)*g/dp 
                  dsubclwm=dsubclwm+(zum(i,k+1)*clwtot1-zum(i,k)*clwtot)*g/dp 
                  dsubclws=dsubclws+(zus(i,k+1)*clwtot1-zus(i,k)*clwtot)*g/dp 
               endif
               tem  = dt*(outqcs(i,k)*cutens(i)+outqc(i,k)*cuten(i)       &
                      +outqcm(i,k)*cutenm(i)                           &
!                       +dsubclw*xmb(i)+dsubclws*xmbs(i)+dsubclwm*xmbm(i) &
                      )
               tem1 = max(0.0, min(1.0, (tcr-t(i,k))*tcrf))
               if (clw(i,k,2) .gt. -999.0) then
                clw(i,k,1) = max(0.,clw(i,k,1) + tem * tem1)            ! ice
                clw(i,k,2) = max(0.,clw(i,k,2) + tem *(1.0-tem1))       ! water
              else
                clw(i,k,1) = max(0.,clw(i,k,1) + tem)
              endif

            enddo
               gdc(i,1,10)=forcing(i,1)
               gdc(i,2,10)=forcing(i,2)
               gdc(i,3,10)=forcing(i,3)
               gdc(i,4,10)=forcing(i,4)
               gdc(i,5,10)=forcing(i,5)
               gdc(i,6,10)=forcing(i,6)
               gdc(i,7,10)=forcing(i,7)
               gdc(i,8,10)=forcing(i,8)
               gdc(i,10,10)=xmb(i)
               gdc(i,11,10)=xmbm(i)
               gdc(i,12,10)=xmbs(i)
               gdc(i,13,10)=hfx(i)
               gdc(i,15,10)=qfx(i)
               gdc(i,16,10)=pret(i)*3600.
            if(ktop(i).gt.2 .and.pret(i).gt.0.)dt_mf(i,ktop(i)-1)=ud_mf(i,ktop(i))
            endif
            enddo
            do i=its,itf
              if(pret(i).gt.0.)then
                 cactiv(i)=1
                 raincv(i)=.001*(cutenm(i)*pretm(i)+cutens(i)*prets(i)+cuten(i)*pret(i))*dt
              else
                 cactiv(i)=0
                 if(pretm(i).gt.0)raincv(i)=.001*cutenm(i)*pretm(i)*dt
              endif   ! pret > 0
            enddo
 100    continue


   end subroutine cu_gf_driver_run
end module cu_gf_driver
