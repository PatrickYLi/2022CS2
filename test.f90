program test
  use patmo
  use patmo_commons
  use patmo_constants
  use patmo_parameters
  use patmo_ode
  use patmo_utils
  implicit none
  real*8::dt,x(speciesNumber),t,tend,imass
  real*8::heff(chemSpeciesNumber)
  real*8::dep(chemSpeciesNumber) !cm/s
  real*8::dn(cellsNumber,speciesNumber)
  integer::icell,i,j

  !init photochemistry
  call patmo_init()

  !load temperature and density profile
  call patmo_loadInitialProfile("profile.dat",unitH="km",unitX="1/cm3")

  !set BB flux (default Sun@1AU)
  call patmo_setFluxBB()
  call patmo_setGravity(9.8d2)
  !call patmo_setEddyKzzAll(1.0d5)
  
  !read initial value 
  call patmo_dumpHydrostaticProfile("hydrostat.out")
  wetdep(:,:) = 0d0

   !calculate wet deposition
   call computewetdep(1,2.0d-2)     !OCS
   call computewetdep(20,5.0d-2)    !CS2
	call computewetdep(10,4.0d3)     !SO2
   
 !va(:) = 0d0  
 !pa(:) = 0d0  
 
!  open(60,file="vapor_H2SO4.txt",status="old")  
!    do i=13,34
!       read(60,*) va(i)
!	end do
!  close(60)

!  open(61,file="partial_H2SO4.txt",status="old") 
!    do i=13,34
!       read(61,*) pa(i)
!	end do
!  close(61)


 !gd(:) = 0d0   
   
!  open(62,file="SO4_deposition_rate.txt",status="old")  
!    do i=1,60
!       read(62,*) gd(i)
!	end do
!  close(62)

  
  !get initial mass, g/cm3
  imass = patmo_getTotalMass()
  print *,"mass:",imass

  !loop on time 
  dt = secondsPerDay
  tend = secondsPerDay * 365d0*10d0
  t = 0d0

  !loop on time
  do

     dt = dt
	 
	 call patmo_run(dt)

	 	 t = t + dt
		 
if(t==315360000d0)then 
   call patmo_dumpDensityToFile(35,t,patmo_idx_CS2)
 	call patmo_dumpDensityToFile(36,t,patmo_idx_COS)
	call patmo_dumpDensityToFile(37,t,patmo_idx_SO2)
	call patmo_dumpDensityToFile(38,t,patmo_idx_SCSOH)
 	call patmo_dumpDensityToFile(39,t,patmo_idx_S2)
  	call patmo_dumpDensityToFile(40,t,patmo_idx_SH)
   call patmo_dumpDensityToFile(41,t,patmo_idx_HSO)
   call patmo_dumpDensityToFile(42,t,patmo_idx_S)
   call patmo_dumpDensityToFile(43,t,patmo_idx_SO)
	call patmo_dumpDensityToFile(44,t,patmo_idx_CS2E)
   call patmo_dumpDensityToFile(45,t,patmo_idx_CS)
   call patmo_dumpDensityToFile(46,t,patmo_idx_HSO2)
end if

! do i=1,cellsNumber
     ! write(27,*)  krate(i,40), krate(i,39)  !O2,O3
     ! write(28,*)  krate(i,38), krate(i,41), krate(i,44)  !OCS,CS2,H2S
     ! write(29,*)  krate(i,42), krate(i,43), krate(i,45)  !SO3,SO2,SO
! end do

!do i=1,cellsNumber
!      write(27,*)  krate(i,63), krate(i,73), krate(i,74) 
!end do


 print '(F11.2,a2)',t/tend*1d2," %"
     if(t>=tend) exit
  end do
  
  !get mass, g/cm3
  imass = patmo_getTotalMass()
  print *,"mass:",imass
  
  !dump final hydrostatic equilibrium
  call patmo_dumpHydrostaticProfile("hydrostatEnd.out")
  call patmo_dumpAllRates("rates.dat")
  call patmo_dumpAllReverseRates("reverseRate.dat")
  call patmo_dumpJValue("J_Value.dat")

end program test
!**************
    subroutine computewetdep(i,heff)
      use patmo_commons
      use patmo_constants
      use patmo_parameters
      implicit none
      real*8::gamma(cellsNumber)  ! Precipation and Nonprecipitation time 
      real*8::wh2o(cellsNumber)   ! Rate of wet removal
      real*8::rkj(cellsNumber,chemSpeciesNumber)    ! Average Remeval Frequency	  
      real*8::y(cellsNumber),fz(cellsNumber),wl,qj(cellsNumber,chemSpeciesNumber)
	   real*8::heff !Henry's Constant
      real*8::zkm(cellsNumber),temp(cellsNumber),gam15,gam8
	   integer::i,j
	 !Gas constant
      real*8,parameter::Rgas_atm = 1.36d-22 !Latm/K/mol   original 
      !real*8,parameter::Rgas_atm =  8.2057d-02!Latm/K/mol  test run


      gam15 = 8.64d5/2d0
      gam8 = 7.0d6/2d0
      wl = 1d0
      zkm(:) = height(:)/1d5
	   temp(:) = TgasAll(:)
	 
   do j=1,12

	   !FIND APPROPRIATE GAMMA
        if (zkm(j).LE.1.51d0) then
           gamma(j) = gam15
        else if (zkm(j).LT.8d0) then
           gamma(j) = gam15 + (gam8-gam15)*((zkm(j)-1.5d0)/6.5d0)
        else
           gamma(j) = gam8
        end if 

       !FIND WH2O
        if (zkm(j).LE.1d0) then
           y(j) = 11.35d0 + 1d-1*zkm(j)
        else
           y(j) = 11.5444d0 - 0.085333d0*zkm(j) - 9.1111d-03*zkm(j)*zkm(j)
        end if
        wh2o(j) = 10d0**y(j)

	   !FIND F(Z)
        if (zkm(j).LE.1.51d0) then
           fz(j) = 1d-1
        else
           fz(j) = 0.16615d0 - 0.04916d0*zkm(j) + 3.37451d-3*zkm(j)*zkm(j)
        end if 
		
	   !Raintout rates
        rkj(j,i) = wh2o(j)/55d0 /(av*wl*1.0d-9 + 1d0/(heff*Rgas_atm*temp(j)))
	     qj(j,i) = 1d0 - fz(j) + fz(j)/(gamma(j)*rkj(j,i)) * (1d0 - EXP(-rkj(j,i)*gamma(j)))
        wetdep(j,i) = (1d0 - EXP(-rkj(j,i)*gamma(j)))/(gamma(j)*qj(j,i))
	end do

	!Output 
   if (i==1) then
  	do j=1,12
      open  (20,file="Rainout-OCS.txt")
      write (20,*) 'GAMMA', gamma(j)
      write (20,*) 'ZKM', zkm(j)
      write (20,*) 'WH2O', wh2o(j)
	   write (20,*) 'RKJ', rkj(j,i)
 	   write (20,*) 'QJ', qj(j,i)
	   write (20,*) 'K_RAIN',  wetdep(j,i)
   end do
   end if
	 	 
   if (i==20) then
	do j=1,12
      open  (25,file="Rainout-CS2.txt")
      write (25,*) 'ZKM', zkm(j)
	   write (25,*) 'K_RAIN',  wetdep(j,i)
   end do
   end if 	
   
   if (i==10) then
   	do j=1,12
      open  (24,file="Rainout-SO2.txt")
      write (24,*) 'ZKM', zkm(j)
	   write (24,*) 'K_RAIN',  wetdep(j,i)
      end do
   end if 

   end subroutine computewetdep
	!**************