module dang_param_mod
    use healpix_types
    use dang_util_mod
    use hashtbl
    implicit none

    type, public :: params
        ! Global parameters
        integer(i4b)                                  :: ngibbs        ! Number of Gibbs iterations
        integer(i4b)                                  :: nsample       ! For internal samplers (MH)
        integer(i4b)                                  :: iter_out      ! Out put maps every <- iterations
        integer(i4b)                                  :: cg_iter       ! Maximum cg iterations
        integer(i4b)                                  :: bp_burnin     ! Number of burn in samples for BP chains
        integer(i4b)                                  :: bp_max        ! Maximum number of maps from BP chains
        integer(i4b)                                  :: num_chains    ! Number of bp chains used
        logical(lgt)                                  :: bp_swap       ! Do the BP map swapping?
        logical(lgt)                                  :: output_fg     ! Do we output the foregrounds at each frequency?
        logical(lgt)                                  :: output_unc    ! Do we output uncertainty of template fit?
        character(len=512)                            :: outdir        ! Output directory
        character(len=512)                            :: bp_chains     ! bp chains, read as a string, moved to a 'list'
        character(len=16)                             :: ml_mode       ! 'sample' or 'optimize'
        character(len=16)                             :: solver        ! Linear system solver type 
        character(len=16)                             :: mode          ! 'dang' mode ('comp_sep', 'HI_fit')
        character(len=5)                              :: tqu           ! Which pol_type to sample
        real(dp)                                      :: cg_converge   ! CG convergence criterion 
        integer(i4b), allocatable, dimension(:)       :: pol_type      ! Points above to map number
        character(len=512), allocatable, dimension(:) :: bp_chain_list ! This is where the bp_chains string goes
                                                  
        ! Data parameters
        integer(i4b)                                    :: numband       ! Number of bands total in parameter file
        integer(i4b)                                    :: numinc        ! Number of bands to include in the fit
        character(len=512)                              :: datadir       ! Directory to look for bandfiles in
        character(len=512)                              :: bp_dir        ! Directory for BP swap maps
        character(len=512)                              :: mask_file     ! Mask filename
        character(len=512), allocatable, dimension(:)   :: band_label     ! Band label
        character(len=512), allocatable, dimension(:)   :: band_mapfile   ! Band filename
        character(len=512), allocatable, dimension(:)   :: band_noisefile ! Band rms filename
        character(len=512), allocatable, dimension(:)   :: band_unit      ! Band units (uK_CMB, uK_RJ, MJy/sr)
        real(dp),           allocatable, dimension(:)   :: band_nu        ! Band frequency (in GHz)
        real(dp),           allocatable, dimension(:)   :: init_gain     ! initial gain value for each band
        real(dp),           allocatable, dimension(:)   :: init_offs     ! initial offset value for each band
        logical(lgt),       allocatable, dimension(:)   :: bp_map        ! True false (know when to swap)
        logical(lgt),       allocatable, dimension(:)   :: fit_gain      ! Do we fit the gain for this band?
        logical(lgt),       allocatable, dimension(:)   :: fit_offs      ! Do we fit the offset for this band?
        logical(lgt),       allocatable, dimension(:)   :: band_inc      ! Is this band included?
        
        ! Component parameters
        integer(i4b)                                      :: ncomp          ! # of foregrounds
        integer(i4b)                                      :: ntemp          ! # of templates 

        character(len=64)                                 :: dust_corr_type ! Dust correction type (uniform/planck)
        logical(lgt),       allocatable, dimension(:)     :: dust_corr      ! Storing which bands should be dust corrected

        character(len=512), allocatable, dimension(:)     :: temp_file      ! Template Filename
        character(len=512), allocatable, dimension(:)     :: temp_label     ! Template label
        logical(lgt),       allocatable, dimension(:,:)   :: temp_corr      ! Storing which bands should have templates fit
        integer(i4b),       allocatable, dimension(:)     :: temp_nfit      ! Number of bands fit for template i

        logical(lgt),       allocatable, dimension(:)     :: fg_inc         ! Logical - include fg?
        character(len=512), allocatable, dimension(:)     :: fg_label       ! Fg label (for outputs)
        character(len=512), allocatable, dimension(:,:)   :: fg_ind_region  ! Fg spectral index sampler (pixel/fullsky)
        real(dp),           allocatable, dimension(:,:)   :: fg_init        ! Initialized parameter value (fullsky)
        real(dp),           allocatable, dimension(:,:,:) :: fg_gauss       ! Fg gaussian sampling parameters
        integer(i4b),       allocatable, dimension(:)     :: fg_ref_loc     ! Fg reference band
        logical(lgt),       allocatable, dimension(:,:)   :: fg_samp_spec   ! Logical - sample fg parameter?
        logical(lgt),       allocatable, dimension(:)     :: fg_samp_amp    ! Logical - sample fg amplitude
        integer(i4b),       allocatable, dimension(:,:)   :: fg_samp_nside  ! Fg parameter nside sampling
        logical(lgt),       allocatable, dimension(:,:)   :: fg_spec_joint  ! Logical - sample fg spec param jointly in Q and U?
        character(len=512), allocatable, dimension(:,:)   :: fg_spec_file   ! Fg spectral parameter input map
        character(len=512), allocatable, dimension(:)     :: fg_type        ! Fg type (power-law feks)
        real(dp),           allocatable, dimension(:)     :: fg_nu_ref      ! Fg reference frequency
        real(dp),           allocatable, dimension(:,:,:) :: fg_uni         ! Fg sampling bounds

        integer(i4b)                                      :: njoint         ! # of components to jointly sample 
        logical(lgt)                                      :: joint_sample   ! Logical - jointly sample fg amplitudes
        logical(lgt)                                      :: joint_pol      ! Points to which Stokes are jointly sampled
        character(len=512), allocatable, dimension(:)     :: joint_comp     ! Joint sampler components

        real(dp),           allocatable, dimension(:,:)   :: mbb_gauss      ! MBB Gaussian sampling params for thermal dust subtraction

        real(dp)                                          :: thresh         ! Threshold for the HI fitting (sample pixels under thresh)
        character(len=512)                                :: HI_file        ! HI map filename
        character(len=512)                                :: HI_Td_init     ! HI fitting dust temp estimate
        real(dp)                                          :: HI_Td_mean     ! HI Temperature sampling mean
        real(dp)                                          :: HI_Td_std      ! HI Temperature sampling std

    end type params

contains

    subroutine get_file_length(filename,length)
        implicit none
        character(len=512), intent(in)  :: filename
        integer(i4b),       intent(out) :: length
        integer(i4b), parameter    :: maxdepth = 256
        integer(i4b)               :: depth, units(maxdepth), i
        character(len=512)         :: key, value, filenames(maxdepth), line

        length = 0
        depth = 1
        units(depth) = getlun()
        filenames(depth) = filename
        open(units(depth),file=trim(filename),status="old")!,err=4)
        do while(depth >= 1)
            read(units(depth),*,end=1) key
            if (key(1:1)=='#') cycle
            backspace(units(depth))

            if (key(1:1)=='@') then
                if(key == '@INCLUDE') then
                    ! Recurse into the new file                                                             
                    read(units(depth),*,end=1) key, value
                    depth=depth+1
                    units(depth) = getlun()
                    filenames(depth) = value
                    open(units(depth),file=value,status="old")!,err=2)
                else
                    stop
                end if
            else
                read(units(depth),fmt="(a)") line
                !if we get here we have read a new line from the parameter file(s)              
                length = length + 1
            end if
            cycle
            ! We get here if we reached the end of a file. Close it and                                   
            ! return to the file above.                                                                   
        1      close(units(depth))
            !write(*,*) "Exiting file " // filenames(depth)                                               
            depth = depth-1
        end do
        return

    end subroutine get_file_length

    subroutine read_param_file(par)
        implicit none
        type(hash_tbl_sll)                            :: htable
        type(params), intent(inout)                   :: par
        integer(i4b)                                  :: parfile_len, i
        character(len=512)                            :: paramfile
        character(len=512), allocatable, dimension(:) :: parfile_cache

        call getarg(1,paramfile)

        write(*,*) ''
        if (rank == master) write(*,*) 'Reading parameters from ', trim(paramfile)
        write(*,*) ''

        call get_file_length(paramfile,parfile_len)
        allocate(parfile_cache(parfile_len))
        call read_paramfile_to_ascii(paramfile,parfile_cache)

        !Initialize a hash table                                                                         
        call init_hash_tbl_sll(htable,tbl_len=10*parfile_len)
        ! Put the parameter file into the hash table                                                     
        call put_ascii_into_hashtable(parfile_cache,htable)
        !deallocate(parfile_cache)
 
        call read_global_params(htable,par)    
        call read_data_params(htable,par)
        call read_comp_params(htable,par)
        deallocate(parfile_cache)

    end subroutine read_param_file

    subroutine read_paramfile_to_ascii(paramfile,paramfile_cache)
        implicit none
        character(len=512),                            intent(in)    :: paramfile
        character(len=512), allocatable, dimension(:), intent(inout) :: paramfile_cache
        integer(i4b), parameter   :: maxdepth = 256
        integer(i4b)              :: depth, units(maxdepth), line_nr, paramfile_len, i
        character(len=512)        :: key, value, filenames(maxdepth), line

        line_nr = 0
        depth   = 1
        units(depth) = getlun()
        filenames(depth) = paramfile
        open(units(depth),file=trim(paramfile),status="old")!,err=4)
        do while(depth >= 1)
            read(units(depth),*,end=1) key
            if (key(1:1)=='#') cycle
            backspace(units(depth))

            if (key(1:1)=='@') then
                if(key == '@INCLUDE') then
                    ! Recurse into the new file                                                             
                    read(units(depth),*,end=1) key, value
                    depth=depth+1
                    units(depth) = getlun()
                    filenames(depth) = value
                    open(units(depth),file=value,status="old")!,err=2)
                else
                    stop
                end if
            else
                read(units(depth),fmt="(a)") line
                !if we get here we have read a new line from the parameter file(s)                         
                line_nr = line_nr + 1
                write(paramfile_cache(line_nr),fmt="(a)") line
            end if
            cycle
        1   close(units(depth))
            depth = depth-1
        end do
        return

    end subroutine read_paramfile_to_ascii

    subroutine put_ascii_into_hashtable(asciitbl,htbl)
        implicit none
        character(len=512), allocatable, dimension(:), intent(in) :: asciitbl
        type(hash_tbl_sll), intent(inout) :: htbl
        character(len=512) :: key, val
        character(len=256) :: toks(2)
        integer            :: i, n
        do i = 1,size(asciitbl)
           call get_tokens(trim(asciitbl(i)), "=", group="''" // '""', maxnum=2, toks=toks, num=n)
           if(n < 2) then ! only need the lines where one has 'key'='value'                                                                   
              cycle
           end if
           key = get_token(toks(1), " ", 1, group="''" // '""')
           val = get_token(toks(2), " ", 1, group="''" // '""')
           call tolower(key)  ! we don't differentiate btw. upper and lower case                                                              
           if (key=="") cycle ! we don't need blank lines                                                                                      
           call put_hash_tbl_sll(htbl,trim(key),trim(val))
        end do
        return
    
        write(*,*) "Error: Cannot read ascii line:", i, "line = '" // trim(asciitbl(i)) // "'"
        stop
    
    end subroutine put_ascii_into_hashtable

      ! read parameter from input argument or hash table                                                 
    subroutine get_parameter_hashtable(htbl, parname, len_itext, par_int, par_char, &
        & par_string, par_sp, par_dp, par_lgt, par_present, desc)
        implicit none
        type(hash_tbl_sll), intent(in) :: htbl 
        character(len=*),   intent(in) :: parname
        integer(i4b),         optional :: len_itext
        integer(i4b),         optional :: par_int
        character(len=*),     optional :: par_char
        character(len=*),     optional :: par_string
        real(sp),             optional :: par_sp
        real(dp),             optional :: par_dp
        logical(lgt),         optional :: par_lgt
        logical(lgt),         optional :: par_present
        character(len=*),     optional :: desc

        logical(lgt)               :: found

        ! found = .false.
        ! call get_parameter_arg(parname, par_int, par_char, par_string, par_sp, par_dp, par_lgt, found, desc)
        ! if(found) then
        !    if(present(par_present)) par_present = .true.
        ! else
        call get_parameter_from_hash(htbl, parname, len_itext, par_int, &
             & par_char, par_string, par_sp, par_dp, par_lgt, par_present, desc)
        ! end if
    end subroutine get_parameter_hashtable

      ! getting parameter value from hash table                                                          
    subroutine get_parameter_from_hash(htbl, parname, len_itext, par_int, par_char, &
        & par_string, par_sp, par_dp, par_lgt, par_present, desc)
        implicit none
        type(hash_tbl_sll), intent(in) :: htbl
        character(len=*),   intent(in) :: parname
        integer(i4b),     optional :: len_itext
        integer(i4b),     optional :: par_int
        character(len=*), optional :: par_char
        character(len=*), optional :: par_string
        real(sp),         optional :: par_sp
        real(dp),         optional :: par_dp
        logical(lgt),     optional :: par_lgt
        logical(lgt),     optional :: par_present
        character(len=*), optional :: desc
        character(len=256)         :: key
        character(len=:), ALLOCATABLE   :: itext,jtext
        CHARACTER(len=:), ALLOCATABLE   :: val,val2,val3
        integer(i4b)                    :: i,j

        key=adjustl(trim(parname))
        call tolower(key)
        call get_hash_tbl_sll(htbl,trim(key),val)
        if (.not. allocated(val)) then
            goto 1
            if (.not. present(len_itext)) goto 1
            allocate(character(len=len_itext) :: itext,jtext)
            itext=key(len(trim(key))-(len_itext-1):len(trim(key)))
            call get_hash_tbl_sll(htbl,'band_default_params'//trim(itext),val2)
            if (allocated(val2)) then
               read(val2,*) j
               if (j /= 0) then
                  call int2string(j, jtext)
                  call get_hash_tbl_sll(htbl,'band_default_params'//trim(jtext),val3)
                  if (allocated(val3)) then
                     read(val3,*) i
                     if (i /= 0) goto 2
                  end if
                  call get_hash_tbl_sll(htbl,key(1:len(trim(key))-len_itext)//trim(jtext),val)
                  if (.not. allocated(val)) goto 3
               else
                  goto 1
               end if
            else
               goto 1
            end if
            deallocate(itext,jtext)
        end if
     
        if (present(par_int)) then
            read(val,*) par_int
        elseif (present(par_char)) then
            read(val,*) par_char
        elseif (present(par_string)) then
            read(val,*) par_string
        elseif (present(par_sp)) then
            read(val,*) par_sp
        elseif (present(par_dp)) then
            read(val,*) par_dp
        elseif (present(par_lgt)) then
            read(val,*) par_lgt
        else
            write(*,*) "get_parameter: Reached unreachable point!"
        end if
        
        deallocate(val)
        return
         
    1   write(*,*) "Error: Could not find parameter '" // trim(parname) // "'"
        write(*,*) ""
        stop
         
         
    2   write(*,*) "Error: Recursive default parameters, bands " // &
            & trim(jtext) // " and " //trim(itext)
        write(*,*) ""
        stop
         
    3   write(*,*) "Error: Could not find parameter '" // trim(parname) // &
            & "' from default '"//key(1:len(trim(key))-len_itext)//trim(jtext)//"'"
        write(*,*) ""
        stop
         
    end subroutine get_parameter_from_hash
   
    subroutine read_global_params(htbl,par)
        implicit none

        type(hash_tbl_sll), intent(in)    :: htbl
        type(params),       intent(inout) :: par
        integer(i4b)                      :: pol_count

        integer(i4b)     :: i, j, n, len_itext
        character(len=2) :: itext
        character(len=2) :: jtext

        write(*,*) "Read global parameters."

        call get_parameter_hashtable(htbl, 'OUTPUT_DIRECTORY', par_string=par%outdir)
        call get_parameter_hashtable(htbl, 'NUMGIBBS', par_int=par%ngibbs)
        call get_parameter_hashtable(htbl, 'NUMSAMPLE', par_int=par%nsample)
        call get_parameter_hashtable(htbl, 'OUTPUT_ITER', par_int=par%iter_out)
        call get_parameter_hashtable(htbl, 'OUTPUT_COMPS', par_lgt=par%output_fg)
        call get_parameter_hashtable(htbl, 'SOLVER_TYPE', par_string=par%solver)
        call get_parameter_hashtable(htbl, 'SOLVER_MODE', par_string=par%mode)
        call get_parameter_hashtable(htbl, 'ML_MODE', par_string=par%ml_mode)
        call get_parameter_hashtable(htbl, 'TQU', par_string=par%tqu)
        call get_parameter_hashtable(htbl, 'CG_ITER_MAX', par_int=par%cg_iter)
        call get_parameter_hashtable(htbl, 'CG_CONVERGE_THRESH', par_dp=par%cg_converge)
        call get_parameter_hashtable(htbl, 'OUTPUT_TEMP_UNCERTAINTY', par_lgt=par%output_unc)
        call get_parameter_hashtable(htbl, 'BP_SWAP',par_lgt=par%bp_swap)
        call get_parameter_hashtable(htbl, 'BP_BURN_IN',par_int=par%bp_burnin)
        call get_parameter_hashtable(htbl, 'BP_MAX_ITER',par_int=par%bp_max)
        call get_parameter_hashtable(htbl, 'BP_DIRECTORY',par_string=par%bp_dir)
        call get_parameter_hashtable(htbl, 'BP_CHAINS_LIST',par_string=par%bp_chains)
        call get_parameter_hashtable(htbl, 'BP_NUM_CHAINS',par_int=par%num_chains)

        allocate(par%bp_chain_list(par%num_chains))

        call delimit_string(par%bp_chains,',',par%bp_chain_list)
        
        ! Surely an inefficient way to decide which maps to use (T -> 1, Q -> 2, U -> 3), but it works
        pol_count = 0
        if (index(par%tqu,'T') /= 0) then
            pol_count = pol_count + 1
        end if
        if (index(par%tqu,'Q') /= 0) then
            pol_count = pol_count + 1
        end if
        if (index(par%tqu,'U') /= 0) then
            pol_count = pol_count + 1
        end if
        allocate(par%pol_type(pol_count))
        
        pol_count = 0
        if (index(par%tqu,'T') /= 0) then
            pol_count = pol_count + 1
            par%pol_type(pol_count) = 1
        end if
        if (index(par%tqu,'Q') /= 0) then
            pol_count = pol_count + 1
            par%pol_type(pol_count) = 2
        end if
        if (index(par%tqu,'U') /= 0) then
            pol_count = pol_count + 1
            par%pol_type(pol_count) = 3
        end if
        
        par%outdir = trim(par%outdir) // '/'

    end subroutine read_global_params

    subroutine read_data_params(htbl,par)
        implicit none

        type(hash_tbl_sll), intent(in)    :: htbl
        type(params),       intent(inout) :: par

        integer(i4b)     :: i, j, n, len_itext
        character(len=3) :: itext
        character(len=2) :: jtext

        write(*,*) "Read data parameters."

        len_itext = len(trim(itext))

        call get_parameter_hashtable(htbl, 'NUMBAND',    par_int=par%numband)
        call get_parameter_hashtable(htbl, 'NUMINCLUDE',    par_int=par%numinc)
        call get_parameter_hashtable(htbl, 'DATA_DIRECTORY', par_string=par%datadir)
        call get_parameter_hashtable(htbl, 'MASKFILE', par_string=par%mask_file)

        n = par%numband

        allocate(par%band_mapfile(n),par%band_label(n))
        allocate(par%band_noisefile(n),par%band_nu(n))
        allocate(par%band_unit(n))
        allocate(par%bp_map(n))
        allocate(par%dust_corr(n))
        allocate(par%band_inc(n))

        allocate(par%init_gain(n))
        allocate(par%init_offs(n))
        allocate(par%fit_gain(n))
        allocate(par%fit_offs(n))

        do i = 1, n
            call int2string(i, itext)
            call get_parameter_hashtable(htbl, 'INCLUDE_BAND'//itext, len_itext=len_itext, par_lgt=par%band_inc(i))
            call get_parameter_hashtable(htbl, 'BAND_LABEL'//itext, len_itext=len_itext, par_string=par%band_label(i))
            call get_parameter_hashtable(htbl, 'BAND_FILE'//itext, len_itext=len_itext, par_string=par%band_mapfile(i))
            call get_parameter_hashtable(htbl, 'BAND_RMS'//itext, len_itext=len_itext, par_string=par%band_noisefile(i))
            call get_parameter_hashtable(htbl, 'BAND_FREQ'//itext, len_itext=len_itext, par_dp=par%band_nu(i))
            call get_parameter_hashtable(htbl, 'BAND_UNIT'//itext, len_itext=len_itext, par_string=par%band_unit(i))
            call get_parameter_hashtable(htbl, 'BAND_INIT_GAIN'//itext, len_itext=len_itext, par_dp=par%init_gain(i))
            call get_parameter_hashtable(htbl, 'BAND_FIT_GAIN'//itext, len_itext=len_itext, par_lgt=par%fit_gain(i))
            !call get_parameter_hashtable(htbl, 'BAND_INIT_OFFSET'//itext, len_itext=len_itext, par_dp=par%init_offs(i))
            call get_parameter_hashtable(htbl, 'BAND_BP'//itext, len_itext=len_itext, par_lgt=par%bp_map(i))
            call get_parameter_hashtable(htbl, 'DUST_CORR'//itext, len_itext=len_itext, par_lgt=par%dust_corr(i))
         end do
    end subroutine read_data_params

    subroutine read_comp_params(htbl,par)
        implicit none

        type(hash_tbl_sll), intent(in)    :: htbl
        type(params),       intent(inout) :: par

        integer(i4b)     :: i, j, n, n2, n3
        integer(i4b)     :: len_itext, len_jtext
        character(len=2) :: itext
        character(len=3) :: jtext

        write(*,*) "Read component parameters."

        len_itext = len(trim(itext))
        len_jtext = len(trim(jtext))


        if (trim(par%mode) == 'comp_sep') then
           call get_parameter_hashtable(htbl, 'NUMCOMPS', par_int=par%ncomp)
           call get_parameter_hashtable(htbl, 'NUMTEMPS', par_int=par%ntemp)
           call get_parameter_hashtable(htbl, 'NUMJOINT', par_int=par%njoint)
           call get_parameter_hashtable(htbl, 'JOINT_SAMPLE', par_lgt=par%joint_sample)
           call get_parameter_hashtable(htbl, 'JOINT_POL', par_lgt=par%joint_pol)
           call get_parameter_hashtable(htbl, 'DUST_CORR_TYPE', par_string=par%dust_corr_type)

           allocate(par%mbb_gauss(2,2))

           call get_parameter_hashtable(htbl, 'MBB_TD_MEAN',par_dp=par%mbb_gauss(1,1))
           call get_parameter_hashtable(htbl, 'MBB_TD_STD',par_dp=par%mbb_gauss(1,2))
           call get_parameter_hashtable(htbl, 'MBB_BETA_MEAN',par_dp=par%mbb_gauss(2,1))
           call get_parameter_hashtable(htbl, 'MBB_BETA_STD',par_dp=par%mbb_gauss(2,2))
           
           n  = par%ncomp
           n2 = par%ntemp
           n3 = par%njoint
           
           allocate(par%fg_label(n),par%fg_type(n),par%fg_nu_ref(n),par%fg_ref_loc(n))
           allocate(par%fg_inc(n),par%fg_samp_amp(n))
           allocate(par%fg_spec_joint(n,2))
           allocate(par%fg_gauss(n,2,2),par%fg_uni(n,2,2))
           allocate(par%fg_samp_nside(n,2),par%fg_samp_spec(n,2))
           allocate(par%fg_spec_file(n,2))
           allocate(par%fg_ind_region(n,2))
           allocate(par%fg_init(n,2))
           par%temp_nfit = 0

           allocate(par%temp_file(n2))
           allocate(par%temp_nfit(n2))
           allocate(par%temp_label(n2))
           allocate(par%temp_corr(n2,par%numband))
                      
           allocate(par%joint_comp(n3))

           do i = 1, n2
              call int2string(i, itext)
              call get_parameter_hashtable(htbl, 'TEMPLATE_FILENAME'//itext, len_itext=len_itext, par_string=par%temp_file(i))
              call get_parameter_hashtable(htbl, 'TEMPLATE_LABEL'//itext, len_itext=len_itext, par_string=par%temp_label(i))
              do j = 1, par%numband
                 call int2string(j,jtext)
                 call get_parameter_hashtable(htbl, 'TEMPLATE'//trim(itext)//'_FIT'//jtext,&
                      len_itext=len_jtext,par_lgt=par%temp_corr(i,j))
                 if (par%temp_corr(i,j)) then
                    par%temp_nfit(i) = par%temp_nfit(i) + 1
                 end if
              end do
           end do

           do i = 1, n3
              call int2string(i, itext)
              call get_parameter_hashtable(htbl, 'JOINT_SAMPLE_COMP'//itext, len_itext=len_itext, par_string=par%joint_comp(i))
           end do

           do i = 1, n
              call int2string(i, itext)
              call get_parameter_hashtable(htbl, 'COMP_LABEL'//itext, len_itext=len_itext, par_string=par%fg_label(i))
              call get_parameter_hashtable(htbl, 'COMP_TYPE'//itext, len_itext=len_itext, par_string=par%fg_type(i))
              if (trim(par%fg_type(i)) /= 'template') then
                 call get_parameter_hashtable(htbl, 'COMP_REF_FREQ'//itext, len_itext=len_itext, par_dp=par%fg_nu_ref(i))
              end if
              call get_parameter_hashtable(htbl, 'COMP_INCLUDE'//itext, len_itext=len_itext, par_lgt=par%fg_inc(i))
              call get_parameter_hashtable(htbl, 'COMP_SAMPLE_AMP'//itext, len_itext=len_itext, par_lgt=par%fg_samp_amp(i))

              if (trim(par%fg_type(i)) == 'power-law') then
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_GAUSS_BETA_MEAN'//itext, len_itext=len_itext,&
                      par_dp=par%fg_gauss(i,1,1))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_GAUSS_BETA_STD'//itext, len_itext=len_itext,&
                      par_dp=par%fg_gauss(i,1,2))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_UNI_BETA_LOW'//itext, len_itext=len_itext,&
                      par_dp=par%fg_uni(i,1,1))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_UNI_BETA_HIGH'//itext, len_itext=len_itext,&
                      par_dp=par%fg_uni(i,1,2))
                 call get_parameter_hashtable(htbl, 'COMP_BETA'//itext, len_itext=len_itext, par_dp=par%fg_init(i,1))
                 call get_parameter_hashtable(htbl, 'COMP_BETA_SAMP_NSIDE'//itext, len_itext=len_itext,&
                      par_int=par%fg_samp_nside(i,1))
                 call get_parameter_hashtable(htbl, 'COMP_BETA_SAMPLE'//itext, len_itext=len_itext,&
                      par_lgt=par%fg_samp_spec(i,1))
                 call get_parameter_hashtable(htbl, 'COMP_BETA_JOINT'//itext, len_itext=len_itext,&
                      par_lgt=par%fg_spec_joint(i,1))
                 call get_parameter_hashtable(htbl, 'COMP_BETA_INPUT_MAP'//itext, len_itext=len_itext,&
                      par_string=par%fg_spec_file(i,1))
                 call get_parameter_hashtable(htbl, 'COMP_BETA_REGION'//itext, len_itext=len_itext,&
                      par_string=par%fg_ind_region(i,1))
              else if (trim(par%fg_type(i)) == 'mbb') then
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_GAUSS_BETA_MEAN'//itext, len_itext=len_itext,&
                      par_dp=par%fg_gauss(i,1,1))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_GAUSS_BETA_STD'//itext, len_itext=len_itext,&
                      par_dp=par%fg_gauss(i,1,2))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_UNI_BETA_LOW'//itext, len_itext=len_itext,&
                      par_dp=par%fg_uni(i,1,1))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_UNI_BETA_HIGH'//itext, len_itext=len_itext,&
                      par_dp=par%fg_uni(i,1,2))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_GAUSS_T_MEAN'//itext, len_itext=len_itext,&
                      par_dp=par%fg_gauss(i,2,1))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_GAUSS_T_STD'//itext, len_itext=len_itext,&
                      par_dp=par%fg_gauss(i,2,2))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_UNI_T_LOW'//itext, len_itext=len_itext,&
                      par_dp=par%fg_uni(i,2,1))
                 call get_parameter_hashtable(htbl, 'COMP_PRIOR_UNI_T_HIGH'//itext, len_itext=len_itext,&
                      par_dp=par%fg_uni(i,2,2))
                 call get_parameter_hashtable(htbl, 'COMP_BETA_INPUT_MAP'//itext, len_itext=len_itext,&
                      par_string=par%fg_spec_file(i,1))
                 call get_parameter_hashtable(htbl, 'COMP_BETA_SAMP_NSIDE'//itext, len_itext=len_itext,&
                      par_int=par%fg_samp_nside(i,1))
                 call get_parameter_hashtable(htbl, 'COMP_BETA_SAMPLE'//itext, len_itext=len_itext,&
                      par_lgt=par%fg_samp_spec(i,1))
                 call get_parameter_hashtable(htbl, 'COMP_T_SAMP_NSIDE'//itext, len_itext=len_itext,&
                      par_int=par%fg_samp_nside(i,2))
                 call get_parameter_hashtable(htbl, 'COMP_T_SAMPLE'//itext, len_itext=len_itext,&
                      par_lgt=par%fg_samp_spec(i,2))
                 call get_parameter_hashtable(htbl, 'COMP_T_INPUT_MAP'//itext, len_itext=len_itext,&
                      par_string=par%fg_spec_file(i,2))
              end if
              if (trim(par%fg_type(i)) /= 'template') then
                 par%fg_ref_loc(i) = minloc(abs(par%band_nu-par%fg_nu_ref(i)),1)
              end if
           end do



        else if (trim(par%mode) == 'hi_fit') then
           call get_parameter_hashtable(htbl, 'NUMTEMPS', par_int=par%ntemp)
           call get_parameter_hashtable(htbl,'HI_THRESH', par_dp=par%thresh)
           call get_parameter_hashtable(htbl,'HI_FILE',par_string=par%HI_file)
           call get_parameter_hashtable(htbl,'T_MAP_INIT',par_string=par%HI_Td_init)
           call get_parameter_hashtable(htbl,'T_MEAN',par_dp=par%HI_Td_mean)
           call get_parameter_hashtable(htbl,'T_STD',par_dp=par%HI_Td_std)

           n2            = par%ntemp

           allocate(par%temp_file(n2))
           allocate(par%temp_label(n2))
           allocate(par%temp_nfit(n2))
           allocate(par%temp_corr(n2,par%numband))

           par%temp_corr(1,:) = .true.

        end if

    end subroutine read_comp_params

    subroutine delimit_string(string, delimiter, list)
      implicit none
      character(len=*), intent(in)                :: string, delimiter
      character(len=*), dimension(:), intent(out) :: list
      integer(i4b)                                :: i, j, k

      j = 1
      k = 1
      do i=1,len_trim(string)
         if (string(i:i) == trim(delimiter)) then
            list(k) = trim(string(j:i-1))
            j = i+1
            k = k + 1
         end if
      end do

      if (k < len(list)+1) then
         list(k) = trim(string(j:))
      end if

    end subroutine delimit_string

    function get_token(string, sep, num, group, allow_empty) result(res)
        implicit none
        character(len=*)           :: string, sep
        character(len=len(string)) :: res
        character(len=*), optional :: group
        logical(lgt),     optional :: allow_empty
        integer(i4b)               :: i, num, ext(2)
        ext = -1
        do i = 1, num
            call tokenize(string, sep, ext, group, allow_empty)
        end do
        res = string(ext(1):ext(2))
    end function get_token

    ! Fill all tokens into toks, and the num filled into num                                           
    subroutine get_tokens(string, sep, toks, num, group, maxnum, allow_empty)
        implicit none
        character(len=*) :: string, sep
        character(len=*) :: toks(:)
        character(len=*), optional :: group
        integer(i4b),     optional :: num, maxnum
        logical(lgt),     optional :: allow_empty
        integer(i4b) :: n, ext(2), nmax
        ext = -1
        n = 0
        nmax = size(toks); if(present(maxnum)) nmax = maxnum
        call tokenize(string, sep, ext, group, allow_empty)
        do while(ext(1) > 0 .and. n < nmax)
            n = n+1
            toks(n) = string(ext(1):ext(2))
            call tokenize(string, sep, ext, group, allow_empty)
        end do
        if(present(num)) num = n
    end subroutine get_tokens
    
    subroutine tokenize(string, sep, ext, group, allow_empty)
        implicit none
        character(len=*) :: string, sep
        character(len=*), optional   :: group
        character(len=256)  :: op, cl
        integer(i4b), save           :: level(256), nl
        integer(i4b), intent(inout)  :: ext(2)
        logical(lgt), optional       :: allow_empty
    
        integer(i4b) :: i, j, o, c, ng
        logical(lgt) :: intok, hit, empty
    
        empty = .false.; if(present(allow_empty)) empty = allow_empty
    
        if(ext(2) >= len(string)) then
           ext = (/ 0, -1 /)
           return
        end if
        ng = 0
        if(present(group)) then
            ng = len_trim(group)/2
            do i = 1, ng
                op(i:i) = group(2*i-1:2*i-1)
                cl(i:i) = group(2*i:2*i)
            end do
        end if
        if(ext(2) <= 0) then
            level = 0
            nl = 0
        end if
        intok = .false.
        j     = 1
        do i = ext(2)+2, len(string)
            hit = .false.
            c = index(cl(1:ng), string(i:i))
            if(c /= 0) then; if(level(c) > 0) then
                level(c) = level(c) - 1
                if(level(c) == 0) nl = nl - 1
                hit = .true.
            end if; end if
            if(nl == 0) then
                ! Are we in a separator or not                                                             
                if(index(sep, string(i:i)) == 0) then
                    ! Nope, so we must be in a token. Register start of token.                              
                    if(.not. intok) then
                        j = i
                        intok = .true.
                    end if
                else
                    ! Yes. This either means that a token is done, and we should                            
                    ! return it, or that we are waiting for a new token, in                                 
                    ! which case do nothing.                                                                
                    if(intok) then
                        ext = (/ j, i-1 /)
                        return
                    elseif(empty) then
                       ext = (/ i, i-1 /)
                       return
                    end if
                end if
            end if
            o = index(op(1:ng), string(i:i))
            if(o /= 0 .and. .not. hit) then
                if(level(o) == 0) nl = nl + 1
                level(o) = level(o) + 1
            end if
        end do
        ! Handle last token                                                                              
        if(intok) then
            ext = (/ j, i-1 /)
        elseif(empty) then
            ext = (/ i, i-1 /)
        else
            ext = (/ 0, -1 /)
        end if
    end subroutine tokenize

end module dang_param_mod
