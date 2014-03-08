
set(B_BUILD_SET_OPTIONS)
set(B_BUILD_SET_SINGLE_ARGS
		NAME
		GXX_COMPILER_VERSION
		VCC_VERSION
		BUILD_DIR
		DOC_DIR
		MAYA_ENVIRONMENT_DIR
		CPP_LIB_INSTALL_DIR)
set(B_BUILD_SET_MULTI_ARGS
		EXCLUDE
		INCLUDE
		GXX_COMPILER_FLAGS
		ADDITIONAL_ARGS
		SDKS)
		

# ==============================================================================
# may_build_project(RESULT_VARIABLE PROJECT_ID
#							${CMAKE_SYSTEM_NAME] ...)
# Query of a project with your given ID may be built
# RESULT_VARIABLE will be a true value if the given project may build
# PROJECT_ID the project to query
# ARGN
# 	are zero or more flags specifying the operating system that the project may build on
#	valid names are all valid values of CMAKE_SYSTEM_NAME.
#	If no platform is given, it will not be taken into consideration.
# ==============================================================================
function(may_build_project RESULT_VARIABLE PROJECT_ID)
	if(ARGN)
		list(FIND ARGN ${CMAKE_SYSTEM_NAME} SYSTEM_NAME_INDEX)
		if(SYSTEM_NAME_INDEX EQUAL -1)
			set(${RESULT_VARIABLE} NO PARENT_SCOPE)
			return()
		endif()
	endif()# end handle platform
	
	if(B_BUILD_SET_INCLUDE)
		regex_list_matches(REGEX_INDEX B_BUILD_SET_INCLUDE ${PROJECT_ID})
		set(${RESULT_VARIABLE} NO PARENT_SCOPE)
		if(REGEX_INDEX GREATER -1)
			set(${RESULT_VARIABLE} YES PARENT_SCOPE)
		endif()
	elseif(B_BUILD_SET_EXCLUDE)
		regex_list_matches(REGEX_INDEX B_BUILD_SET_EXCLUDE ${PROJECT_ID})
		set(${RESULT_VARIABLE} YES PARENT_SCOPE)
		if(REGEX_INDEX GREATER -1)
			set(${RESULT_VARIABLE} NO PARENT_SCOPE)
		endif()
	else()
		# if nothing is given, everything matches
		set(${RESULT_VARIABLE} YES PARENT_SCOPE)
	endif()
endfunction()


# ==============================================================================
# Query the version of the given SDK_NAME to be used and store it in RESULT_VARIABLE.
# SDK_VERSION is the version you would use, and we will check if an override for
# your particular sdk is set and use it.
# NOTE: For the sake of documentation, we will print useful information in 
# case an override is used.
# ==============================================================================
function(sdk_version_override SDK_NAME SDK_VERSION RESULT_VARIABLE)
	list(FIND B_SDK_OVERRIDES ${SDK_NAME} INDEX)
	if(INDEX GREATER -1)
		math(EXPR NEXT_INDEX "${INDEX} + 1")
		list(GET B_SDK_OVERRIDES ${NEXT_INDEX} NEW_SDK_VERSION)
		set(SDK_VERSION ${NEW_SDK_VERSION})
	endif()
	set(${RESULT_VARIABLE} ${SDK_VERSION} PARENT_SCOPE)
endfunction()


# ==============================================================================
# build_set(
#			NAME
#				set_name
#			EXCLUDE
#				project_name_regex [...project_name_regexN]
#			INCLUDE
#				project_name_regex [...project_name_regexN]
#			GXX_COMPILER_VERSION
#				version|NONE
#			GXX_COMPILER_FLAGS
#				compiler_flags [...compiler_flagsN]
#			VCC_VERSION
#				80|90|100|NONE
#			MAYA_ENVIRONMENT_DIR
#				directory
#			BUILD_DIR
#				directory
#			DOC_DIR
#				directory
#			SDKS
#				name version [...nameN versionN]
#			ADDITIONAL_ARGS
#				arg1 [...argN]
#			)
# 
# NAME
#	The name of the build set
# EXCLUDE (mutually exclusive with INCLUDE)
#	Specify project names which should NOT be build. Supports regular expressions.
#	This acts like a black-list.
# INCLUDE (mutually exclusive with EXCLUDE)
#	Specify all projects which should be build. Supports regular expressions.
#	This acts like a white-list.
# GXX_COMPILER_VERSION
#	Specify a compiler version to use on linux and osx. Valid strings would be 4.4 or 4.1.2 for example.
#	If the compiler cannot be found or if it doesn't actually match the given version,
#	the whole build set will fail.
#	May assume the special value NONE in which case this value will be ignored.
#	However, in that case cpp projects may not be built on linux either.
# GXX_COMPILER_FLAGS
#	Additional flags that should be passed to each invocation of GCC, no matter
#	which CMAKE_BUILD_TYPE is currently set.
# VCC_VERSION
#	Specify which visual studio version to use on windows.
# 	80 corresponds to visual studio 2005, 90 will be visual studios 2008 and so forth.
#	May assume the special value NONE, in which case the compiler version is ignored.
#	However, this also means that windows projects may not be built either.
# MAYA_ENVIRONMENT_DIR (optional)
#	relative or absolute path to the environment containing all maya files
#	and plug-ins.
#	Relative paths are interpreted relative to the CMAKE_SOURCE_DIR
# 	If unset, there will be a reasonable default.
# 	TODO: REVIEW: This variable should go, as it is related to the distribution
#	of files. This needs revision anyway, and we probably shouldn't specify this here
# BUILD_DIR (optional)
#	A directory into which to put all the binary data, like compiled object files.
#	These files are considered intermediate as they can be recreated from source.
#	By default, it will be your cmake configuration directory.
#	You should usually define this variable on the commandline
# DOC_DIR (optional)
#	The base directory for all documentation to be build. If relative, its interpreted
#	relative to the CMAKE_SOURCE_DIR.
#	If unset, the default location is CMAKE_CURRENT_BINARY_DIR/doc
#	Otherwise projects will place themselves into the doc directory, which
#	includes their version.
# CPP_LIB_INSTALL_DIR
#	Root directory into which to put all libraries built so far.
# 	If unset, it will default to something reasonable
# ADDITIONAL_ARGS (optional)
#	Any amount of arguments to be readable by other CMake files that we might
#	pull in. This allow you to use the build-system and its base-configuration
# 	to build custom cmake projects which are just piggybacking in a way.
# SDKS (optional)
# 	A list of sdk names with their desired version.
#	Use this to override version of respective SDKs used by projects.
# NOTE: Currently, all platforms are assumed to be 64 bits
# This function sets the following globally available variables
# B_BUILD_SET_NAME
#	the name of the build set
# B_BUILD_SET_INCLUDE
#	project names you want to include
# B_BUILD_SET_EXCLUDE
#	project_names you want to exclude
# B_GXX_COMPILER_VERSION
#	The gcc/g++ version you want to use.
# B_GXX_COMPILER_FLAGS
#	Additional compiler/linker flags. They are passed to each invocation of gcc.
#	May be unset if no additional flags where specified.
# B_VCC_VERSION
#	the visual studio version to use.
# B_MAYA_ENVIRONMENT_DIR
#	Directory containing all maya related files, like plug-ins and scripts
# B_BUILD_DIR (optional)
#	Base directory into which to put intermediate compiled files.
# B_DOC_DIR
#	Base directory that is to contain all documentation
# B_ADDITIONAL_ARGS
#	All additional arguments other cmake scripts might want to use
# B_SDK_OVERRIDES
#	A list of sdk_name, version pairs to specify preferred versions of sdks to
#	be used by projects.
#	Use sdk_version_override to determine the version you need
# ==============================================================================
function(build_set)
	cmake_parse_arguments(BUILD_SET "${B_BUILD_SET_OPTIONS}" "${B_BUILD_SET_SINGLE_ARGS}" "${B_BUILD_SET_MULTI_ARGS}" ${ARGN})
	
	if(BUILD_SET_UNPARSED_ARGUMENTS)
		error("Some arguments could not be parsed: ${BUILD_SET_UNPARSED_ARGUMENTS}")
	endif()
	
	foreach(VARIABLE ${B_BUILD_SET_SINGLE_ARGS})
		if(${VARIABLE} MATCHES DOC_DIR AND NOT BUILD_SET_${VARIABLE})
			set(BUILD_SET_${VARIABLE} doc)
		endif()
		if(${VARIABLE} MATCHES CPP_LIB_INSTALL_DIR AND NOT BUILD_SET_${VARIABLE})
			set(BUILD_SET_CPP_LIB_INSTALL_DIR ${CMAKE_SOURCE_DIR}/lib/cpp)
		endif()
		
		if(NOT BUILD_SET_${VARIABLE})
			# we have a set of optional values
			if(NOT ${VARIABLE} MATCHES BUILD_DIR|DOC_DIR|MAYA_ENVIRONMENT_DIR)
				error("Please set the ${VARIABLE} parameter of the build set")
			endif()
		else()
			# SANITIZE VARIABLES
			if(${VARIABLE} MATCHES DOC_DIR)
				if(NOT IS_ABSOLUTE ${BUILD_SET_${VARIABLE}})
					set(BUILD_SET_${VARIABLE} ${CMAKE_SOURCE_DIR}/${BUILD_SET_${VARIABLE}})
				endif()
			endif()# sanitice variable
			set(B_${VARIABLE} ${BUILD_SET_${VARIABLE}} CACHE INTERNAL "internal variable" FORCE)
		endif()
	endforeach()
	
	if(BUILD_SET_EXCLUDE AND BUILD_SET_INCLUDE)
		error("Please specify either EXCLUDE or INCLUDE")
	endif()
	
	# MAYA ENVIRONMENT
	###################
	if(NOT BUILD_SET_MAYA_ENVIRONMENT_DIR)
		set(MAYA_ENV_DEFAULT engines/maya/devel)
		trace("Setting B_MAYA_ENVIRONMENT_DIR to ${MAYA_ENV_DEFAULT}") 
		set(BUILD_SET_MAYA_ENVIRONMENT_DIR ${MAYA_ENV_DEFAULT})
	endif()
	
	if(NOT IS_ABSOLUTE ${BUILD_SET_MAYA_ENVIRONMENT_DIR})
		set(BUILD_SET_MAYA_ENVIRONMENT_DIR ${CMAKE_SOURCE_DIR}/${BUILD_SET_MAYA_ENVIRONMENT_DIR})
	endif()
	
	if(NOT IS_DIRECTORY ${BUILD_SET_MAYA_ENVIRONMENT_DIR})
		error("Maya Environment directory at ${BUILD_SET_MAYA_ENVIRONMENT_DIR} did not exist")
	endif()
	
	# ADDITINOAL VARIABLES
	########################
	set(B_BUILD_SET_NAME ${BUILD_SET_NAME} CACHE INTERNAL "Name of the currently set build set" FORCE)
	set(B_BUILD_SET_INCLUDE ${BUILD_SET_INCLUDE} CACHE INTERNAL "project names to include" FORCE)
	set(B_BUILD_SET_EXCLUDE ${BUILD_SET_EXCLUDE} CACHE INTERNAL "project names to exclude" FORCE)
	set(B_MAYA_ENVIRONMENT_DIR ${BUILD_SET_MAYA_ENVIRONMENT_DIR} CACHE INTERNAL "location of the maya environment" FORCE)
	set(B_GXX_COMPILER_FLAGS ${BUILD_SET_GXX_COMPILER_FLAGS} CACHE INTERNAL "additional flags for the gxx compiler" FORCE)
	set(B_ADDITIONAL_ARGS ${BUILD_SET_ADDITIONAL_ARGS} CACHE INTERNAL "Additional flags to be used by anyone" FORCE)
	set(B_SDK_OVERRIDES ${BUILD_SET_SDKS} CACHE INTERNAL "Versions of sdks to use instead" FORCE)
	set(B_CPP_LIB_INSTALL_DIR ${BUILD_SET_CPP_LIB_INSTALL_DIR} CACHE INTERNAL "Directory under which libraries should be installed" FORCE)
	string(REPLACE ";" ", " COMA_SEPARATED_SDK_OVERRIDES "${BUILD_SET_SDKS}")
	prominent_info("Using build-set ${BUILD_SET_NAME}| Excluded ${BUILD_SET_EXCLUDE} | Included ${BUILD_SET_INCLUDE} | SDK Overrides: ${COMA_SEPARATED_SDK_OVERRIDES} | GCC ${B_GXX_COMPILER_VERSION} | MSVC ${B_VCC_VERSION}")
endfunction()
