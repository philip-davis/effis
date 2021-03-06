module kittie
	use kittie_internal

	implicit none


    interface kittie_put
        module procedure kittie_put_real_8_1
        module procedure kittie_put_real_8_2
        module procedure kittie_put_real_8_3
        module procedure kittie_put_real_8_4
        module procedure kittie_put_real_4_2
        module procedure kittie_put_complex_8_6
        module procedure kittie_put_real_8_6
        module procedure kittie_put_integer
        module procedure kittie_put_integer_8_1
        module procedure kittie_put_integer_8_2
        module procedure kittie_put_integer_4_2
        module procedure kittie_put_integer_8_4
        module procedure kittie_put_real_8
    end interface kittie_put


    interface kittie_get_selection
        module procedure kittie_get_selection_integer_1
        module procedure kittie_get_selection_integer_8_1
        module procedure kittie_get_selection_integer_8_2
        module procedure kittie_get_selection_integer_4_2
        module procedure kittie_get_selection_integer_8_4
        module procedure kittie_get_selection_real_8_1
        module procedure kittie_get_selection_real_8_2
        module procedure kittie_get_selection_real_8_3
        module procedure kittie_get_selection_real_8_4
        module procedure kittie_get_selection_complex_8_6
        module procedure kittie_get_selection_real_8_6
    end interface kittie_get_selection


    interface kittie_get
        module procedure kittie_get_integer
        module procedure kittie_get_real_8
    end interface kittie_get


	type coupling_helper
		character(len=:), allocatable :: filename
		type(adios2_engine) :: engine
		type(adios2_io) :: io
		integer :: mode
		integer :: comm
		integer :: rank
		logical :: usesfile
		logical :: alive=.false.
		character(len=:), allocatable :: engine_type

		logical :: timed=.false., timeinit=.false.
		character(len=:), allocatable :: timingfile, timinggroup
		real(8), dimension(1) :: starttime, endtime, othertime, totaltime
		real(8), dimension(1) :: opentime_a, begintime_a, endtime_a
		type(adios2_engine) :: timeengine
		type(adios2_io) :: timingio

	end type coupling_helper


	type(coupling_helper), pointer :: common_helper
	type(coupling_helper), dimension(:), allocatable, target :: helpers
	character(len=8), parameter :: writing=".writing"
	character(len=8), parameter :: reading=".reading"

	! These need to be read from files at startup
	integer :: ngroupnames, ncodes, nnames
	character(len=128), dimension(:), allocatable :: groupnames, codenames, names, engines
	character(len=128), dimension(:, :), allocatable :: plots, params, values
	integer, dimension(:), allocatable :: nplots, nparams

	character(len=:), allocatable :: myreading, app_name
	character(len=128), dimension(:), allocatable :: allreading
	logical, dimension(:), allocatable :: readexists


	contains

		subroutine kittie_read_helpers_file(filename)
			character(len=*), intent(in) :: filename
			character(len=128) :: appname
			logical :: exists
			namelist /setup/ ngroupnames, appname
			namelist /helpers_list/ groupnames

			inquire(file=trim(filename), exist=exists)
			if (exists) then
				open(unit=iounit, file=trim(filename), action='read')
				read(iounit, nml=setup)
				close(iounit)
				allocate(groupnames(ngroupnames), helpers(ngroupnames))
				open(unit=iounit, file=trim(filename), action='read')
				read(iounit, nml=helpers_list)
				close(iounit)
			else
				ngroupnames = 0
				appname = "unknown"
			end if
			app_name = string_copy(appname)

		end subroutine kittie_read_helpers_file


		subroutine kittie_read_codes_file(filename)
			character(len=*), intent(in) :: filename
			character(len=128) :: codename
			logical :: exists
			integer :: pid, i, j, k
			namelist /codes/ ncodes, codename
			namelist /codes_list/ codenames

			inquire(file=trim(filename), exist=exists)
			if (exists) then
				open(unit=iounit, file=trim(filename), action='read')
				read(iounit, nml=codes)
				close(iounit)
				allocate(codenames(ncodes))
				open(unit=iounit, file=trim(filename), action='read')
				read(iounit, nml=codes_list)
				close(iounit)

				myreading = string_copy(reading // '-' // trim(codename))
				allocate(allreading(ncodes))
				do i=1, ncodes
					allreading(i) = trim(reading) // '-' // trim(codenames(i))
				end do
			else
				codename = ""
				myreading = string_copy(reading)
				ncodes = 1
				allocate(allreading(ncodes))
				allreading(1) = trim(reading)
			end if

		end subroutine kittie_read_codes_file


		subroutine kittie_get_helper(groupname, helper)
			character(len=*), intent(in) :: groupname
			type(coupling_helper), pointer, intent(out) :: helper
			integer :: i
			do i=1, size(helpers)
				if (trim(groupname) == trim(groupnames(i))) then
					helper => helpers(i)
					exit
				end if
			end do
		end subroutine kittie_get_helper


		subroutine kittie_read_groups_file(filename)
			character(len=*), intent(in) :: filename
			logical :: exists
			integer :: maxsize, maxparams, i, ierr
			type(adios2_io) :: io
			namelist /ionames/ nnames
			namelist /ionames_list/ names, engines, nplots, nparams
			namelist /plots_list/ plots
			namelist /params_list/ params, values

			inquire(file=trim(filename), exist=exists)

			if (exists) then

				open(unit=iounit, file=trim(filename), action='read')
				read(iounit, nml=ionames)
				close(iounit)

				allocate(names(nnames), engines(nnames), nplots(nnames), nparams(nnames))
				do i=1, nnames
					engines(i) = ""
					nplots(i) = 0
					nparams(i) = 0
				end do
				open(unit=iounit, file=trim(filename), action='read')
				read(iounit, nml=ionames_list)
				close(iounit)

				if (nnames > 0) then
					maxsize = maxval(nplots)
					maxparams = maxval(nparams)
					allocate(plots(nnames, maxsize), params(nnames, maxparams), values(nnames, maxparams))
					open(unit=iounit, file=trim(filename), action='read')
					read(iounit, nml=plots_list)
					close(iounit)
					open(unit=iounit, file=trim(filename), action='read')
					read(iounit, nml=params_list)
					close(iounit)
				end if

			end if

		end subroutine kittie_read_groups_file


		subroutine wlock(wfile)
			character(len=*), intent(in) :: wfile
			logical :: exists
			inquire(file=trim(wfile), exist=exists)
			if (.not. exists) then
				call touch_file(wfile)
			end if
		end subroutine wlock

		subroutine nothing_writing(wfile)
			character(len=*), intent(in) :: wfile
			logical :: exists
			inquire(file=trim(wfile), exist=exists)
			do while(exists)
				inquire(file=trim(wfile), exist=exists)
			end do
		end subroutine nothing_writing

		subroutine nothing_reading(helper)
			type(coupling_helper), intent(in) :: helper
			integer :: i
			character(len=512) :: rfile
			logical :: readexists
			do i=1, ncodes
				rfile = trim(helper%filename) // trim(allreading(i))
				inquire(file=trim(rfile), exist=readexists)
				do while(readexists)
					inquire(file=trim(rfile), exist=readexists)
				end do
			end do
		end subroutine

		subroutine wait_data_existence(helper)
			type(coupling_helper), intent(in) :: helper
			logical :: exists
			inquire(file=trim(helper%filename), exist=exists)
			do while(.not.exists) 
				inquire(file=trim(helper%filename), exist=exists)
			end do
		end subroutine wait_data_existence

		subroutine rlock(rfile)
			character(len=*), intent(in) :: rfile
			logical :: exists
			inquire(file=trim(rfile), exist=exists)
			if (.not. exists) then
				call touch_file(rfile)
			end if
		end subroutine rlock


		recursive subroutine until_nonexistent(helper, verify_level)
			type(coupling_helper), intent(in) :: helper
			integer, intent(in), optional :: verify_level
			logical :: rexists, wexists, redo, found
			integer :: v, vlevel, i
			character(len=512) :: rfile, wfile

			if (present(verify_level)) then
				vlevel = verify_level
			else
				vlevel = 3
			end if
			redo = .false.

			wfile = trim(helper%filename) // writing

			if (helper%mode == adios2_mode_write) then
				call wlock(wfile)
				call nothing_reading(helper)
			else
				rfile = trim(helper%filename) // myreading
				call wait_data_existence(helper)
				call nothing_writing(wfile)
				call rlock(rfile)

				do v=1, vlevel
					inquire(file=trim(wfile), exist=wexists)
					if (wexists) then
						call delete_existing(rfile)
						redo = .true.
						exit
					end if
				end do

			end if

			if (redo) then
				call until_nonexistent(helper, verify_level=vlevel)
			end if

		end subroutine until_nonexistent


		subroutine lock_logic(helper, yes)
			type(coupling_helper), intent(in) :: helper
			logical, intent(in) :: yes

			if (yes) then
				call until_nonexistent(helper)
			else
				if (helper%mode == adios2_mode_write) then
					call delete_existing(helper%filename//writing)
				else if (helper%mode == adios2_mode_read) then
					call delete_existing(helper%filename//myreading)
				end if
			end if

		end subroutine lock_logic


		subroutine lock_state(helper, yes)
			type(coupling_helper), intent(in) :: helper
			logical, intent(in) :: yes
			integer :: ierr, rank, stat

			if (.not.yes) then
				call mpi_barrier(helper%comm, ierr)
			end if

			if (helper%rank == 0) then
				call lock_logic(helper, yes)
			end if

			if (yes) then
				call mpi_barrier(helper%comm, ierr)
			end if

		end subroutine lock_state

		subroutine kittie_close(helper, ierr)
			type(coupling_helper), intent(inout) :: helper
			integer, intent(out) :: ierr
			if (helper%engine%valid) then
				call adios2_close(helper%engine, ierr)
			end if
		end subroutine kittie_close

		subroutine kittie_couple_end_step(helper, ierr, time)
			type(coupling_helper), intent(inout) :: helper
			integer, intent(out) :: ierr
			logical, intent(in), optional :: time

			if (helper%timed .and. use_mpi) then
				helper%othertime(1) = mpi_wtime() - helper%othertime(1)
				helper%endtime(1) = mpi_wtime()
			end if

			if (helper%usesfile) then
				call lock_state(helper, .true.)
			end if

#			ifdef FINE_TIME
				helper%endtime_a(1) = mpi_wtime()
#			endif

			call adios2_end_step(helper%engine, ierr)

#			ifdef FINE_TIME
				helper%endtime_a(1) = mpi_wtime() - helper%endtime_a(1)
#			endif

			if (helper%usesfile) then
				call lock_state(helper, .false.)

				if (helper%mode == adios2_mode_read) then
					call adios2_close(helper%engine, ierr)
					call adios2_remove_all_variables(helper%io, ierr)
				end if
			end if

			if (helper%timed .and. use_mpi) then
				helper%totaltime(1) = mpi_wtime() - helper%totaltime(1)
				helper%endtime(1) = mpi_wtime() - helper%endtime(1)
				call adios2_begin_step(helper%timeengine, adios2_step_mode_append, ierr)
				call adios2_put(helper%timeengine, "start", helper%starttime, ierr)
				call adios2_put(helper%timeengine, "end",   helper%endtime,   ierr)
				call adios2_put(helper%timeengine, "other", helper%othertime, ierr)
				call adios2_put(helper%timeengine, "total", helper%totaltime, ierr)

#				ifdef FINE_TIME
					call adios2_put(helper%timeengine, "adios2_open", helper%opentime_a, ierr)
					call adios2_put(helper%timeengine, "adios2_begin_step", helper%begintime_a, ierr)
					call adios2_put(helper%timeengine, "adios2_end_step", helper%endtime_a, ierr)
#				endif

				call adios2_end_step(helper%timeengine, ierr)
			end if

		end subroutine kittie_couple_end_step


		function which_engine(io) result(res)
			type(adios2_io), intent(in) :: io
			integer :: ierr
			character(:), allocatable :: res

			res = capitalize(io%engine_type)
		end function which_engine


		function uses_files(engine_type) result(res)
			character(len=*), intent(in) :: engine_type
			integer :: ierr
			logical :: res

			if ((trim(engine_type) == 'BPFILE') .or. (trim(engine_type) == 'BP') .or. (trim(engine_type) == 'BP3') .or. (trim(engine_type) == 'HDF5')) then
				res = .true.
			else
				res = .false.
			end if
		end function uses_files


		!recursive subroutine file_seek(helper, step)
		function file_seek(helper, step) result(found)
			type(coupling_helper), intent(inout) :: helper
			integer, intent(in) :: step
			integer :: ierr, berr, i
			integer(kind=8) :: current_step, cs
			logical :: found

			found = .false.
			current_step = -1
			call lock_state(helper, .true.)

#			ifdef USE_MPI
				call adios2_open(helper%engine, helper%io, helper%filename, helper%mode, helper%comm, ierr)
#			else
				call adios2_open(helper%engine, helper%io, helper%filename, helper%mode, ierr)
#			endif


			do while (.true.)
				call adios2_begin_step(helper%engine, adios2_step_mode_next_available, 0.0, berr, ierr)

				if (berr == 0) then
					current_step = current_step + 1
				else
					exit
				end if

				if (current_step == step) then
					found = .true.
					exit
				end if

				call adios2_end_step(helper%engine, ierr)
			end do

			call lock_state(helper, .false.)
			if (.not.found) then
				call adios2_close(helper%engine, ierr)
				call adios2_remove_all_variables(helper%io, ierr)
				!call file_seek(helper, step)
			end if

		end function file_seek


		subroutine kittie_couple_open(helper)
			type(coupling_helper), intent(inout) :: helper
			integer :: ierr, rank
			
			if (helper%usesfile) then
				call lock_state(helper, .true.)
			end if

#			ifdef USE_MPI

#				ifdef FINE_TIME
					helper%opentime_a(1) = mpi_wtime()
#				endif

				call adios2_open(helper%engine, helper%io, helper%filename, helper%mode, helper%comm, ierr)

#				ifdef FINE_TIME
					helper%opentime_a(1) = mpi_wtime() - helper%opentime_a(1)
#				endif

#			else
				call adios2_open(helper%engine, helper%io, helper%filename, helper%mode, ierr)
#			endif


			if (helper%usesfile) then
				call lock_state(helper, .false.)
			end if
		end subroutine kittie_couple_open


		subroutine kittie_finalize(ierr)
			integer, intent(out) :: ierr
			integer :: i, rank

			do i=1, size(helpers)
				call kittie_close(helpers(i), ierr)
				if ((helpers(i)%rank == 0) .and. (helpers(i)%mode == adios2_mode_write)) then
					call touch_file(trim(helpers(i)%filename)//'.done')
				end if
			end do

			call adios2_finalize(kittie_adios, ierr)

		end subroutine kittie_finalize


		function setup_file() result(filename)
			logical :: stripped
			character(len=512) :: appfile
			character(len=:), allocatable :: filename
			integer :: i

			stripped = .false.
			call get_command_argument(0, appfile)
			do i=len_trim(appfile), 1, -1
				if (trim(appfile(i:i)) == '/') then
					filename = string_copy(trim(appfile(1:i)) // ".kittie-setup.nml")
					stripped = .true.
					exit
				end if
			end do

			if (.not.stripped) then
				filename = string_copy(".kittie-setup.nml")
			end if

		end function setup_file


#		ifdef USE_MPI

			subroutine kittie_initialize(comm, ierr, xml)
				! Intialize Kittie's ADIOS-2 namespace
				integer, intent(in)  :: comm
				integer, intent(out) :: ierr
				character(len=*), intent(in), optional :: xml
				character(len=:), allocatable :: filename

				if (present(xml)) then
					call adios2_init(kittie_adios, trim(xml), comm, adios2_debug_mode_on, ierr)
				else
					call adios2_init(kittie_adios, comm, adios2_debug_mode_on, ierr)
				end if

				filename = setup_file()
				call kittie_read_helpers_file(filename)
				call kittie_read_codes_file(".kittie-codenames-" // trim(app_name) // ".nml")
				call kittie_read_groups_file(  ".kittie-groups-" // trim(app_name) // ".nml")
				deallocate(filename)

			end subroutine kittie_initialize

#		else

			subroutine kittie_initialize(ierr, xml)
				! Intialize Kittie's ADIOS-2 namespace
				integer, intent(out) :: ierr
				character(len=*), intent(in), optional :: xml
				!if (present(xml)) then
				!	call adios2_init(kittie_adios, trim(xml), adios2_debug_mode_on, ierr)
				!else
				!	call adios2_init(kittie_adios, adios2_debug_mode_on, ierr)
				!end if
				call adios2_init(kittie_adios, adios2_debug_mode_on, ierr)
			end subroutine kittie_initialize

#		endif


		subroutine kittie_declare_io(groupname, ierr)
			! Initialize a new Kittie coupling I/O group
			character(len=*), intent(in) :: groupname
			integer, intent(out) :: ierr
			integer :: i, j
			type(adios2_io) :: io
			call adios2_declare_io(io, kittie_adios, trim(groupname), ierr)
			do i=1, nnames
				if ((trim(names(i)) == trim(groupname)) .and. (trim(engines(i)) /= "")) then
					call adios2_set_engine(io, trim(engines(i)), ierr)
				end if

				do j=1, nparams(i)
					call adios2_set_parameter(io, params(i, j), values(i, j), ierr)
				end do
					
			end do
		end subroutine kittie_declare_io


		function KittieDeclareIO(groupname, ierr) result(io)
			! Initialize a new Kittie coupling I/O group
			character(len=*), intent(in) :: groupname
			integer, intent(out) :: ierr
			integer :: i, j
			type(adios2_io) :: io
			call adios2_declare_io(io, kittie_adios, trim(groupname), ierr)
			do i=1, nnames
				if ((trim(names(i)) == trim(groupname)) .and. (trim(engines(i)) /= "")) then
					call adios2_set_engine(io, trim(engines(i)), ierr)
				end if

				do j=1, nparams(i)
					call adios2_set_parameter(io, trim(params(i, j)), trim(values(i, j)), ierr)
				end do

			end do
		end function KittieDeclareIO


		function KittieDefineVariable(groupname, varname, dtype, ndims, global_dims, global_offsets, local_dims, ierr, constant_dims) result(varid)
			! At least for now, it makes sense to basically use the ADIOS-2 API

			character(len=*), intent(in) :: groupname
			character(len=*), intent(in) :: varname
			integer, intent(in)  :: dtype
			integer, intent(in)  :: ndims
			integer(kind=8), dimension(:), intent(in), optional :: global_dims
			integer(kind=8), dimension(:), intent(in), optional :: global_offsets
			integer(kind=8), dimension(:), intent(in), optional :: local_dims
			integer, intent(out), optional :: ierr
			logical, intent(in), optional :: constant_dims

			integer :: err
			type(adios2_variable) :: varid
			type(adios2_io)       :: io

			call adios2_at_io(io, kittie_adios, trim(groupname), err)

			if (present(global_dims)) then
				if (present(constant_dims)) then
					call adios2_define_variable(varid, io, varname, dtype, ndims, global_dims, global_offsets, local_dims, constant_dims, err)
				else
					call adios2_define_variable(varid, io, varname, dtype, ndims, global_dims, global_offsets, local_dims, adios2_constant_dims, err)
				end if
			else
				call adios2_define_variable(varid, io, varname, dtype, err)
			end if

			if (present(ierr)) then
				ierr = err
			end if

		end function KittieDefineVariable


		subroutine kittie_define_variable(groupname, varname, dtype, ndims, global_dims, global_offsets, local_dims, ierr, constant_dims)
			! At least for now, it makes sense to basically use the ADIOS-2 API

			character(len=*), intent(in) :: groupname
			character(len=*), intent(in) :: varname
			integer, intent(in)  :: dtype
			integer, intent(in)  :: ndims
			integer(kind=8), dimension(:), intent(in), optional :: global_dims
			integer(kind=8), dimension(:), intent(in), optional :: global_offsets
			integer(kind=8), dimension(:), intent(in), optional :: local_dims
			integer, intent(out), optional :: ierr
			logical, intent(in), optional :: constant_dims

			integer :: err
			type(adios2_variable) :: varid
			type(adios2_io)       :: io

			call adios2_at_io(io, kittie_adios, trim(groupname), err)

			if (present(global_dims)) then
				if (present(constant_dims)) then
					call adios2_define_variable(varid, io, varname, dtype, ndims, global_dims, global_offsets, local_dims, constant_dims, err)
				else
					call adios2_define_variable(varid, io, varname, dtype, ndims, global_dims, global_offsets, local_dims, adios2_constant_dims, err)
				end if
			else
				call adios2_define_variable(varid, io, varname, dtype, err)
			end if

			if (present(ierr)) then
				ierr = err
			end if

		end subroutine kittie_define_variable


		function kittie_inquire_variable(helper, varname, ierr) result(varid)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			call adios2_inquire_variable(varid, helper%io, varname, ierr)
		end function kittie_inquire_variable


		function kittie_set_selection(helper, varname, ndim, starts, counts, ierr) result(varid)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_inquire_variable(helper, varname, ierr)
			call adios2_set_selection(varid, ndim, starts, counts, ierr)
		end function kittie_set_selection


		subroutine kittie_get_selection_integer_1(outdata, helper, varname, ndim, starts, counts, ierr)
			integer, intent(out), dimension(:) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_integer_1


		subroutine kittie_get_selection_integer_4_2(outdata, helper, varname, ndim, starts, counts, ierr)
			integer(4), intent(out), dimension(:, :) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_integer_4_2


		subroutine kittie_get_selection_integer_8_1(outdata, helper, varname, ndim, starts, counts, ierr)
			integer(8), intent(out), dimension(:) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_integer_8_1


		subroutine kittie_get_selection_integer_8_2(outdata, helper, varname, ndim, starts, counts, ierr)
			integer(8), intent(out), dimension(:, :) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_integer_8_2


		subroutine kittie_get_selection_integer_8_4(outdata, helper, varname, ndim, starts, counts, ierr)
			integer(8), intent(out), dimension(:, :, :, :) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_integer_8_4

		subroutine kittie_get_selection_real_8_1(outdata, helper, varname, ndim, starts, counts, ierr)
			real(kind=8), intent(out), dimension(:) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_real_8_1


		subroutine kittie_get_selection_real_8_2(outdata, helper, varname, ndim, starts, counts, ierr)
			real(kind=8), intent(out), dimension(:, :) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_real_8_2
	

		subroutine kittie_get_selection_real_8_3(outdata, helper, varname, ndim, starts, counts, ierr)
			real(kind=8), intent(out), dimension(:, :, :) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_real_8_3
		

		subroutine kittie_get_selection_real_8_4(outdata, helper, varname, ndim, starts, counts, ierr)
			real(kind=8), intent(out), dimension(:, :, :, :) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_real_8_4


		subroutine kittie_get_selection_complex_8_6(outdata, helper, varname, ndim, starts, counts, ierr)
			complex(kind=8), intent(out), dimension(:, :, :, :, :, :) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_complex_8_6


		subroutine kittie_get_selection_real_8_6(outdata, helper, varname, ndim, starts, counts, ierr)
			real(kind=8), intent(out), dimension(:, :, :, :, :, :) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: ndim
			integer(8), dimension(:), intent(in) :: starts, counts
			integer, intent(out) :: ierr
			type(adios2_variable) :: varid
			varid = kittie_set_selection(helper, varname, ndim, starts, counts, ierr)
			call adios2_get(helper%engine, varid, outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_selection_real_8_6


		subroutine kittie_get_integer(outdata, helper, varname, ierr)
			integer, intent(out) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(out) :: ierr
			call adios2_get(helper%engine, trim(varname), outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_integer
		

		subroutine kittie_get_real_8(outdata, helper, varname, ierr)
			real(8), intent(out) :: outdata
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(out) :: ierr
			call adios2_get(helper%engine, trim(varname), outdata, adios2_mode_deferred, ierr)
		end subroutine kittie_get_real_8


		subroutine kittie_couple_start(helper, filename, groupname, mode, comm, step, ierr, dir, timefile)
			! Roughly the idea is push/fetch the given step, without worrying about how to do safely for different types of I/O.
			! In detail, this is something of a combination of adios2_open() and adios2_begin_step() depending what engine type you're using.

			type(coupling_helper), intent(inout) :: helper
			character(len=*), intent(in) :: filename
			character(len=*), intent(in) :: groupname
			integer, intent(in) :: mode
			integer, intent(in),  optional :: comm
			integer, intent(in),  optional :: step
			integer, intent(out), optional :: ierr
			character(len=*), intent(in), optional :: dir
			character(len=*), intent(in), optional :: timefile

			type(adios2_io) :: io, timingio
			type(adios2_engine) :: engine
			integer :: iierr, comm_rank, comm_size
			integer(8), dimension(1) :: gdims, offs, locs
			logical :: found

			if (present(timefile) .and. use_mpi) then
				helper%timed = .true.
				helper%timingfile = string_copy(timefile)
				helper%timinggroup = string_copy(trim(groupname)//"-timing")

				if (.not.helper%timeinit) then
					call mpi_comm_rank(comm, comm_rank, iierr)
					call mpi_comm_size(comm, comm_size, iierr)
					gdims(1) = comm_size
					offs(1)  = comm_rank
					locs(1)  = 1
					call kittie_declare_io(trim(helper%timinggroup), iierr)
					call kittie_define_variable(trim(helper%timinggroup), "start",  adios2_type_dp, 1, gdims, offs, locs, iierr)
					call kittie_define_variable(trim(helper%timinggroup), "end", adios2_type_dp, 1, gdims, offs, locs, iierr)
					call kittie_define_variable(trim(helper%timinggroup), "other", adios2_type_dp, 1, gdims, offs, locs, iierr)
					call kittie_define_variable(trim(helper%timinggroup), "total", adios2_type_dp, 1, gdims, offs, locs, iierr)

#					ifdef FINE_TIME
						call kittie_define_variable(trim(helper%timinggroup), "adios2_open", adios2_type_dp, 1, gdims, offs, locs, iierr)
						call kittie_define_variable(trim(helper%timinggroup), "adios2_begin_step", adios2_type_dp, 1, gdims, offs, locs, iierr)
						call kittie_define_variable(trim(helper%timinggroup), "adios2_end_step", adios2_type_dp, 1, gdims, offs, locs, iierr)
#					endif

					call adios2_at_io(helper%timingio, kittie_adios, trim(helper%timinggroup), iierr)

#					ifdef USE_MPI
						call adios2_open(helper%timeengine, helper%timingio, helper%timingfile, adios2_mode_write, comm, iierr)
#					else
						call adios2_open(helper%timeengine, helper%timingio, helper%timingfile, adios2_mode_write, iierr)
#					endif

					helper%timeinit = .true.
				end if
				helper%starttime(1) = mpi_wtime()
				helper%totaltime(1) = mpi_wtime()
			else
				helper%timed = .false.
			end if

			call adios2_at_io(io, kittie_adios, trim(groupname), iierr)

			if (.not.helper%alive) then
				
				if (present(comm)) then
					helper%comm = comm
					call mpi_comm_rank(helper%comm, helper%rank, iierr)
				endif

				helper%engine_type = which_engine(io)
				helper%usesfile = uses_files(helper%engine_type)

				helper%mode = mode
				if (present(dir)) then
					helper%filename = string_copy(trim(dir)//"/"//trim(filename))
				else
					helper%filename = string_copy(trim(filename))
				end if
			end if

			if (.not.helper%alive) then
				helper%io = io
			end if

			if (helper%mode == adios2_mode_write) then
				if (.not.helper%alive) then
					call kittie_couple_open(helper)
				end if

#				ifdef FINE_TIME
					helper%begintime_a(1) = mpi_wtime()
#				endif

				call adios2_begin_step(helper%engine, adios2_step_mode_append, iierr)

#				ifdef FINE_TIME
					helper%begintime_a(1) = mpi_wtime() - helper%begintime_a(1)
#				endif

			else if (helper%mode == adios2_mode_read) then

				if (helper%usesfile) then
					if (.not.present(step)) then
						write (*, "('If reading from file for coupling, must give what step you want to read from')")
						stop
					end if

					!call file_seek(helper, step)

					found = .false.
					do while (.not.found)
						found = file_seek(helper, step)
					end do

				else
					if (.not.helper%alive) then
						call kittie_couple_open(helper)
					end if

#					ifdef FINE_TIME
						helper%begintime_a(1) = mpi_wtime()
#					endif

					call adios2_begin_step(helper%engine, adios2_step_mode_next_available, iierr)

#					ifdef FINE_TIME
						helper%begintime_a(1) = mpi_wtime() - helper%begintime_a(1)
#					endif

				end if

			end if

			helper%alive = .true.
			if (present(ierr)) then
				ierr = iierr
			end if

			if (helper%timed .and. use_mpi) then
				helper%starttime(1) = mpi_wtime() - helper%starttime(1)
				helper%othertime(1) = mpi_wtime()
			end if

		end subroutine kittie_couple_start


		subroutine kittie_put_real_8(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			real(8), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_real_8


		subroutine kittie_put_integer(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer, intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_integer


		subroutine kittie_put_integer_4_2(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer(4), dimension(:, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_integer_4_2


		subroutine kittie_put_integer_8_1(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer(8), dimension(:), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_integer_8_1


		subroutine kittie_put_integer_8_2(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer(8), dimension(:, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_integer_8_2

		subroutine kittie_put_integer_8_4(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			integer(8), dimension(:, :, :, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_integer_8_4

		subroutine kittie_put_real_8_1(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			real(kind=8), dimension(:), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_real_8_1


		subroutine kittie_put_real_8_2(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			real(kind=8), dimension(:, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_real_8_2


		subroutine kittie_put_real_8_3(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			real(kind=8), dimension(:, :, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_real_8_3


		subroutine kittie_put_real_8_4(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			real(kind=8), dimension(:, :, :, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_real_8_4


		subroutine kittie_put_real_4_2(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			real(kind=4), dimension(:, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_real_4_2


		subroutine kittie_put_complex_8_6(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			complex(kind=8), dimension(:, :, :, :, :, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_complex_8_6

		subroutine kittie_put_real_8_6(helper, varname, outdata, ierr)
			type(coupling_helper), intent(in) :: helper
			character(len=*), intent(in) :: varname
			real(kind=8), dimension(:, :, :, :, :, :), intent(in) :: outdata
			integer, intent(out) :: ierr
			call adios2_put(helper%engine, varname, outdata, ierr)
		end subroutine kittie_put_real_8_6

end module kittie

