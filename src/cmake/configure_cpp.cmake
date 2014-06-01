# ==============================================================================
# Apply general configuration that should be valid for all cpp projects
# ==============================================================================
function(configure_cpp)
	if(B_CPP_CONFIGURED)
		error("configure_cpp called multiple times")
	endif()
	
	trace("Configuring CPP settings")
	
	# define the compiler version !
	#################################
	enable_language(CXX)
	
	# for now, we only allow 64 bit builds !
	# On windows, people could easily and accidentally build 32 bits, and 
	# we don't want this to happen unnoticed at least
	if(${CMAKE_CXX_SIZEOF_DATA_PTR} LESS 8)
		if(WIN32)
			warning("Consider using the flag: -G \"${CMAKE_GENERATOR} Win64\" in your cmake command invokation")
		endif()
		error("Currently builds are only allowed using 64 bit configurations")
	endif()
	
	if(UNIX)
		if(NOT B_GXX_COMPILER_VERSION STREQUAL NONE)
			# VERIFY THE COMPILER HAS RIGHT VERSION
			#########################################
			# Its impossible for cmake to set the cpp compiler based on a configuration
			# it gets fed through a cmakelists file. This is because it will actually 
			# find the compiler as the first thing it does.
			# Even forcing the compiler using the force_compiler script (below)
			# cannot prevent it to invalidate its cache.
			# Therefore we just validate the compiler is the expected one and abort
			# if not, providing all the information the user needs to make it better.
			if(NOT CMAKE_CXX_COMPILER)
				error("CMAKE_CXX_COMPILER not set")
			endif()
			
			# verify actual version
			execute_process(COMMAND ${CMAKE_CXX_COMPILER} --version OUTPUT_VARIABLE VERSION_STRING)
			string(REGEX REPLACE ".* ([0-9]\\.[0-9]\\.[0-9]).*" "\\1" COMPILER_VERSION ${VERSION_STRING})
			if(NOT COMPILER_VERSION)
				error("Didn't manage to parse compiler version from string '${VERSION_STRING}' as returned by '${CMAKE_CXX_COMPILER} --version'")
			endif()
			
			if(NOT ${COMPILER_VERSION} STREQUAL ${B_GXX_COMPILER_VERSION})
				platform_id(PLATFORM_ID)
				set(COMPILER_NAME g++-${B_GXX_COMPILER_VERSION})
				# try to help the user a bit
				find_program(MY_CXX_COMPILER_PATH
					NAMES ${COMPILER_NAME}
					PATHS 
						${CMAKE_SOURCE_DIR}/3rdparty/gcc/${B_GXX_COMPILER_VERSION}/${PLATFORM_ID}/bin
					NO_DEFAULT_PATH
						)
				trace("${CMAKE_SOURCE_DIR}/3rdparty/gcc/${B_GXX_COMPILER_VERSION}/${PLATFORM_ID}/bin")
				if(MY_CXX_COMPILER_PATH)
					info("The required compiler was found at ${MY_CXX_COMPILER_PATH}")
				else()
					info("The required compiler named ${COMPILER_NAME} was not found on your system - consider a symlink")
					set(MY_CXX_COMPILER_PATH ${COMPILER_NAME})
				endif() # handle compiler exists
				info("The version of your compiler at ${CMAKE_CXX_COMPILER} (${COMPILER_VERSION}) did not match the required one: ${B_GXX_COMPILER_VERSION}")
				error("Please use the -DCMAKE_CXX_COMPILER=${MY_CXX_COMPILER_PATH} argument to set the compiler in advance, as required by the build set")
			endif() # compiler version doesn't match
		endif() # compiler version is not NONE
	elseif(WIN32)
		if(NOT B_VCC_VERSION STREQUAL NONE) 
			# just check for the correct msvc version
			if(NOT MSVC)
				error("Currently, builds must be performed with Visual Studio. The configured generator is ${CMAKE_GENERATOR}.")
			endif()
			
			# expands to variable like MSVC80, which should then be checked for 
			# existence - if compiling on vc2005 for instance, the variable MSVC80
			# will be set.
			if(NOT DEFINED MSVC${B_VCC_VERSION})
				error("You build set '${B_BULID_SET_NAME}' requires visual studio ${B_VCC_VERSION} for compilation, you use ${CMAKE_GENERATOR} though. Please choose the correct generator")
			endif()
		endif() # vcc version is not NONE
	else()
		error("Unsupported Platform for compiler setup")
	endif()
	
	
	# UNIX COMPILER SETUP
	#####################
	# add the profiling configuration. Its essentially the release config, but
	# compiles with profiling instructions, enabling gprof
	if(UNIX)
		if(NOT CMAKE_BUILD_TYPE)
			error("CMAKE_BUILD_TYPE was not set. Specify it with -DCMAKE_BUILD_TYPE=Debug|Release on the commandline")
		endif()
		
		# this varible is not always set, we just enforce it
		list(APPEND CMAKE_CONFIGURATION_TYPES Release Debug Profile RelWithDebInfo)
		list(REMOVE_DUPLICATES CMAKE_CONFIGURATION_TYPES)
		set(CMAKE_CONFIGURATION_TYPES "${CMAKE_CONFIGURATION_TYPES}" CACHE STRING
			"List of configurations types, which serve as all valid values of CMAKE_BUILD_TYPE"
			FORCE)
		
		# SETUP PROFILE FLAGS
		#######################
		set( CMAKE_CXX_FLAGS_PROFILE "-O3 -DNDEBUG -pg" CACHE STRING
			"Flags used by the C++ compiler during PROFILE builds.")
		set( CMAKE_EXE_LINKER_FLAGS_PROFILE
			"-pg" CACHE STRING
			"Flags used for linking binaries during PROFILE builds.")
		set( CMAKE_SHARED_LINKER_FLAGS_PROFILE
			"-pg" CACHE STRING
			"Flags used by the shared libraries linker during PROFILE builds.")
		mark_as_advanced(
			CMAKE_CXX_FLAGS_PROFILE
			CMAKE_EXE_LINKER_FLAGS_PROFILE
			CMAKE_SHARED_LINKER_FLAGS_PROFILE)
			
		# make sure we see everything! Don't export anything by default
		# for now, without -pedantic, as it prevents compilation of maya thanks to 'extra ;'  - don't know how to disable this
		# Also, the architecture is hardcoded, this is a problem for older maya versions which where 32 bit on osx
		# TODO: put the arch in the config, but make sure its correct on osx for maya plugins automatically
		if(B_GXX_COMPILER_FLAGS)
			string(REPLACE ";" " " ADDITIONAL_COMPILER_FLAGS "${B_GXX_COMPILER_FLAGS}")
		endif()
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden -fPIC -Wall -Wno-long-long -Wno-unknown-pragmas -Wno-strict-aliasing -Wno-comment -Wcast-qual ${ADDITIONAL_COMPILER_FLAGS}" CACHE STRING "" FORCE)
		if(APPLE)
			set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -arch x86_64 -fno-gnu-keywords -fpascal-strings" CACHE STRING "" FORCE)
		endif()
	endif() # unix
	
	
	# FLAG DEFINITION
	###################
	# Some flags we have to use specifically as we want to add per-target properties
	if(WIN32)
		set(LINK_DIR_FLAG "/LIBPATH:")
	else()
		set(LINK_DIR_FLAG "-L")
	endif()
	set(B_LINK_DIR_FLAG ${LINK_DIR_FLAG} CACHE INTERNAL "link directory flag" FORCE)
	
	
	# finally, mark us configured
	set(B_CPP_CONFIGURED YES CACHE INTERNAL "marks cpp projects (generally) configured" FORCE)
endfunction()
