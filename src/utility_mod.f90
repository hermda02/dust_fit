module utility_mod
    use healpix_types
    use mpi
    use omp_lib
    implicit none

    ! Constants
    real(dp)           :: k_B     = 1.3806503d-23
    real(dp)           :: h       = 1.0545726691251021d-34 * 2.d0 * pi
    real(dp)           :: c       = 2.99792458d8
    real(dp)           :: T_CMB   = 2.7255d0
    real(dp)           :: t1, t2, t3
    real(dp)           :: nullval
    real(dp)           :: missval = -1.6375d30
    integer(i4b)       :: ierr, rank, numprocs
    integer(i4b)       :: nbands, npix, nmaps, nside, nfgs
    integer(i4b)       :: iter, niter, ordering, nlheader
    integer(i4b)       :: proc_per_band
    integer(i4b)       :: master      = 0 
    integer(i4b)       :: from_master = 1
    integer(i4b)       :: from_worker = 2
    logical(lgt)       :: anynull
    integer(i4b) status(mpi_status_size)
    character(len=80), dimension(180) :: header
    character(len=80), dimension(3)   :: tqu
    
    public    :: npix, nbands, nmaps, ordering, header


contains 

   subroutine init_mpi()
     implicit none
     call mpi_init(ierr)
     call mpi_comm_rank(MPI_COMM_WORLD, rank, ierr)
     call mpi_comm_size(MPI_COMM_WORLD, numprocs, ierr)
!     if (rank == 0) then
!        write(*,'(a,i8)') ' The number of processors available = ', numprocs
!     end if
   end subroutine init_mpi

   ! Small utility for converting an integer to a string                                              
   subroutine int2string(integer, string)
     implicit none

     integer(i4b),     intent(in)  :: integer
     character(len=*), intent(out) :: string
     
     integer(i4b)               :: temp_int, i, k

     temp_int = integer
     do i = 1, len(string)
        k = temp_int / 10**(len(string)-i)
        write(string(i:i),'(I1)') k
        temp_int = temp_int - k * 10**(len(string)-i)
     end do

   end subroutine int2string

   subroutine tolower(strIn)! result(strOut)
     ! Adapted from http://www.star.le.ac.uk/~cgp/fortran.html (25 May 2012)
     ! Original author: Clive Page - switched to tolower
     
     implicit none
     
     character(len=*), intent(inout) :: strIn
     character(len=len(strIn)) :: strOut
     integer :: i,j
     
     do i = 1, len(strIn)
        j = iachar(strIn(i:i))
        if (j>= iachar("A") .and. j<=iachar("Z") ) then
           strOut(i:i) = achar(iachar(strIn(i:i))+32)
        else
           strOut(i:i) = strIn(i:i)
        end if
     end do
     
     strIn = strOut
     
   end subroutine tolower

    function rand_normal(mean,stdev) result(c)
         double precision :: mean,stdev,c,temp(2),theta,r
         if (stdev <= 0.0d0) then
            write(*,*) "Standard Deviation must be positive."
         else
            call RANDOM_NUMBER(temp)
            r=(-2.0d0*log(temp(1)))**0.5
            theta = 2.0d0*PI*temp(2)
            c= mean+stdev*r*sin(theta)
      end if
    end function


   function getlun()
     implicit none
     integer(i4b) :: getlun
     logical(lgt) :: exists, isopen
     getlun = 9
     do
        getlun = getlun+1
        inquire(unit=getlun,exist=exists)
        if(exists) then
           inquire(unit=getlun,opened=isopen)
           if(.not. isopen) return
        end if
     end do
   end function getlun

end module utility_mod