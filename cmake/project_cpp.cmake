# Module implementing any cpp project

# CONFIGURATION
################
set(B_PROJECT_CPP_FILESPECS *.cpp *.cxx *.c *.C *.h *.hpp)
set(B_PROJECT_CPP_OPTIONS)
set(B_PROJECT_CPP_SINGLE_ARGS
		NAME
		ID
		OUTPUT_NAME
		VERSION
		TYPE
		LIBRARY_SUFFIX
		LIBRARY_PREFIX
		OUTPUT_DIRECTORY
		DOXYFILE_IN
		USE_SDK_HANDLERS)
set(B_PROJECT_CPP_MULTI_ARGS
		AUTHORS
		SOURCE_FILES
		RESOURCE_FILES
		SOURCE_DIRS
		SOURCE_FILES_EXCLUDE
		INCLUDE_DIRS
		LINK_LIBRARIES
		SDKS
		DEFINES
		PLATFORMS)


################
# UTILITIES ###
##############


# ==============================================================================
# Return the install root directory to a cpp library of the given name and version
# ==============================================================================
function(cpp_install_dir RESULT_VARIABLE PROJECT_NAME VERSION)
	# TODO: at some point this should be a build-set defined prefix
	set(${RESULT_VARIABLE} ${CMAKE_SOURCE_DIR}/lib/cpp/${PROJECT_NAME}/${VERSION}/${B_PLATFORM_ID} PARENT_SCOPE)
endfunction()


# ==============================================================================
# Sets up the installation of a library which is built by cmake. We handle disabled
# targets gracefully 
# PROJECT_NAME name of cpp library
# ==============================================================================
function(cpp_install_library PROJECT_NAME TARGET_NAME VERSION)
	if (NOT TARGET ${TARGET_NAME})
		trace("Skipped installation of ${TARGET_NAME} as it is not being built")
		return()
	endif()

	cpp_install_dir(INSTALL_DIR ${PROJECT_NAME} ${VERSION})
	install(TARGETS
				${TARGET_NAME}
			DESTINATION
				${INSTALL_DIR}/lib
			)
endfunction()



# ==============================================================================
# Put the compiler's ID into the RESULT_VARIABLE
# TODO: This should be related to the ABI of the respective cpp compiler, currently
# it isn't the case though for gcc, its quite a non-trivial matter !
# ==============================================================================
function(cpp_compiler_id RESULT_VARIABLE)
	if(UNIX)
		# to stay sane, just ASSUME that the major version will also determine
		# ABI compatibility. This is not actually the case, but for now it should just
		# be enough.
		string(SUBSTRING ${B_GXX_COMPILER_VERSION} 0 1 MAJOR_VERSION)
		set(${RESULT_VARIABLE} "gcc${MAJOR_VERSION}" PARENT_SCOPE)
	elseif(WIN32)
		set(${RESULT_VARIABLE} msvc${B_VCC_VERSION} PARENT_SCOPE)
	else()
		error("Unknown platform: ${CMAKE_SYSTEM}")
	endif()
endfunction()


# ==============================================================================
# boost_libs(RESULT_VARIABLE LIBRARY1 ...LIBRARYN)
# A utility method providing the correct library name in a platform independent 
# manner. Valid library names are the likes of:
# date_time, filesystem, program_options etc.
# It will put all result names into the RESULT_VARIABLE.
# ==============================================================================
function(boost_libs RESULT_VARIABLE)
	if(WIN32)
		set(PREFIX libboost_)
		set(SUFFIX "-vc${B_VCC_VERSION}-mt")
	else()
		# linux like system
		set(PREFIX boost_)
	endif()
	
	foreach(LIB IN LISTS ARGN)
		list(APPEND BOOST_LIBRARIES ${PREFIX}${LIB}${SUFFIX})
	endforeach()
	
	set(${RESULT_VARIABLE} ${BOOST_LIBRARIES} PARENT_SCOPE)
endfunction()

# ==============================================================================
# cpp_lib_path(
#			RESULT_VARIABLE LIB_NAME LIB_VERSION
#			TYPE
#				GENERAL_INCLUDE|INCLUDE|LIBRARY|BINARY|ROOT
#			[NO_COMPILER_ID]
#			)
# This is just a wrapper for sdk_lib_path(), which sets it up for cpp
# automatically. See sdk_lib_path() for reference.
# ==============================================================================
function(cpp_lib_path RESULT_VARIABLE LIB_NAME LIB_VERSION)
	sdk_lib_path(${RESULT_VARIABLE} ${LIB_NAME} ${LIB_VERSION} ${ARGN} 
					LANGUAGE cpp)
	set(${RESULT_VARIABLE} ${${RESULT_VARIABLE}} PARENT_SCOPE)
endfunction()
		
		
# ==============================================================================
# cpp_project(
#						NAME
#								name
#						ID
#								globally_unique_id
#						AUTHORS
#							name1 [...nameN]
#						OUTPUT_NAME
#								name
#						PLATFORMS
#								Linux|Windows (...)
#						VERSION
#								semantic_version
#						TYPE
#								EXECUTABLE|STATIC|MODULE|SHARED
#						SDKS
#							sdk_name	version
#							[...sdk_nameN versionN]	
#						SOURCE_DIRS
#								dir1 [...dir2]
#						SOURCE_FILES_EXCLUDE
#								regex [...regexN]
#						SOURCE_FILES
#								file1 [...fileN]
#						RESOURCE_FILES
#								resource1 [...resourceN]
#						INCLUDE_DIRS
#								dir1 [...dir2]
#						LINK_LIBRARIES
#								lib1 [...lib2]
#						DEFINES
#								def1 [...defN]
#						LIBRARY_SUFFIX
#								.ext
#						LIBRARY_PREFIX
#								lib
#						OUTPUT_DIRECTORY
#								directory
#						DOXYFILE_IN
#								doxyfile_path|DEFAULT
#
# NAME (required)
#	name of the project
# ID (optional)
#	A globally unique id to be used as handle for this project.
#	Its useful if you create multiple targets per project, where the project
#	will keep the same name, yet build multiple times with changing configuration.
# AUTHORS (required)
#	A list of author names in the format
#	"First [Middle] [Last] <localpart@domainpart>"
#	They will be made available as string literal in you build configuration header.
# OUTPUT_NAME (optional)
#	Normally, the output file name is derived from the name of the project.
#	Using this value, you may explicitly specify the output name of your project
# VERSION (required)
#	semantic_version of the project, see http://semver.org/
# PLATFORMS (optional)
#	Optionally list all platforms where this project may compile.
#	Some tools might only be available on some platforms as they are not
#	meant to be portable.
#	Valid values are generally the ones provide by the CMAKE_SYSTEM_NAME variable
# TYPE (required)
#	EXECUTABLE if the target should be an executable that can be run from the
#	commandline
#	STATIC if the target should be a static library that others can link against.
#	MODULE if the target should be a shared module, which is supposed to be loaded
#	by calls to dlopen().
#	SHARED if the target should be a shared library that can be linked in by other
#	executables (or libraries) using the system's linker at program startup.
#	This is useful if the same code is used by multiple shared libararies or if
#	you want to makes sure that certain objects only exist exactly once in a program.
# SDKS (optional)
#	A list of sdk_name, version pairs that identify all your dependencies and
#	the respective version to use.
#	Valid sdks and versions will automatically cause the include path and library
#	path to be modified to include the respective SDK. This allows you to 
#	specify the libraries you actually want to use.
#	If a required sdk or version does not exist, the compilation will stop.
#
#	SDKs will trigger a handler to be executed, which may add specific features
#	based on the respective SDK. See the separate documentation section below.
# USE_SDK_HANDLERS (optional)
#	If it receives a true value, sdk handler will be called. This also means 
#	that we assume extra arguments will be parsed by a handler, and may not trigger
#	an error.
# SOURCE_DIRS (optional, if SOURCE_FILES is set)
#	A list of directories where source files should be searched recursively
#	If no source dir is set, the current one will be used
# SOURCE_FILES_EXCLUDE (optional)
#	One or more regular expressions that will cause a matching filepath, as gathered
#	recursively by the SOURCE_DIRS search, to be excluded from the actual fileset.
#	Use it to exclude specific files or subdirectories for instance, e.g. Test/
#	or ExcludedFile.*
# SOURCE_FILES (optional, if SOURCE_DIRS is set)
#	Explicit list of source files, relative to the current source directory
# RESOURCE_FILES (optional)
#	Additional files which are resources required by the target.
#	The target will be dependent on them, such that they will be regenerated
#	in case there is a custom rule attached to them.
#	This can be useful to place resources in a destination and have them 
#	updated automatically.
# INCLUDE_DIRS (optional)
#	List directories to be added to the include path
#	If no include directory is used, the one containing the CMakeFile.txt will be used.
# LINK_LIBRARIES (optional)
#	List of library names that should be linked into your output file.
#	To keep the interface simple, if the names differ between windows and linux,
#	you have to manage these names yourselve using a conditional statement.
#	Linux libraries imply the 'lib' prefix, thus you must not prefix it here.
# DEFINES (optional)
#	A list of all preprocessor definitions that serve as mere options similar t
#	#define OPTION
# LIBRARY_SUFFIX (optional)
#	If set, the suffix will be used as file extension in case of 
#	MODULE or SHARED library target's output names.
#	If unset, the system default will be used.
# LIBRARY_PREFIX (optional)
#	If set, the string will be prefixed to the output names of MODULE or SHARED
#	library targets.
#	If unset, the system's defaults will be used.
#	Even though it may be empty using an empty string "", it may also take the 
#	special value NONE to indicate no prefix should be used
# OUTPUT_DIRECTORY (optional)
#	Specify where to put the compiled output of this project.
#	Relative paths will be relative to the CMAKE_CURRENT_BINARY_DIR .
#	If not specified, it will default to a unique path within the binary output
#	directory.
#	Please note that we will always place the output in a unique directory. 
#	As we cannot properly control the actual output directory of files on windows,
#	files will be copied as post-build step.
# DOXYFILE_IN (optional)
#	If set to the path of a doxygen configuration file, it will be used to build
#	doxygen docuementation.
#	It will be piped through the configure_file() framework, which allows you to
#	substitute variables.
#	See this this URL for more information: http://www.cmake.org/cmake/help/v2.8.8/cmake.html#command:configure_file.
#	It can have the built-in value DEFAULT, in which cause the default doxygen
#	template is used.
#
# GENERAL CONFIGURATION
# ----------------------
#	The version information, as well as additional information about your project,
#	can be retrieved in a header file called
#	build_configuration.h
#	In your project, you should include it with 
#	#include "build_configuration.h"
#	and use its preprocessor definitions, for instance, to retrieve the 
#	current project version.
#
# SDK HANDLERS
# -----------------------
#   There might be particular requirements or utilities provided by an sdk.
#	Some might provide additional tools to process source code in one way
#	or another.
#	To enable handlers, set the USE_SDK_HANDLERS argument to YES. 
#	The handler will be called *after* the parent cpp project was created, and it
#	must be named as follows:
#	
#	<name>_sdk_handler.cmake
#
#	Where <name> is the name of your particular sdk, like 'qt'.
#	The handler may access all variables defined so far, and may query and use
#	the parent project using the $PROJECT_ID variable.
#
#	The implementation must be happening in the module directly
#	TODO: Maybe we can keep redefining the same function to actually get a
#	a common signature we can call ?
#
#	HANDLER ARGUMENTS
#   -----------------------
#		If your handler supports arguments, those must be placed *after* 
#		an *option* or a *single-value* option. If it is placed after a
#		multi-value option, the handler's arguments will become a part of it for the
#		parent function.
#		
#		The way to implement this is to amend your options to the B_PROJECT_CPP_*
#		variables in parent scope respectively, and to use it for parsing ARGN.
#		This way, subsequent handlers will not stumble on arguments you have
#		already parsed.
# ==============================================================================
function(cpp_project)
	cmake_parse_arguments(PROJECT
								"${B_PROJECT_CPP_OPTIONS}"
								"${B_PROJECT_CPP_SINGLE_ARGS}" 
								"${B_PROJECT_CPP_MULTI_ARGS}"
								${ARGN})
								
	# allow unparsed arguments if we have handler support
	set(UNPARSED_ARGS "${PROJECT_UNPARSED_ARGUMENTS}")
	if (PROJECT_USE_SDK_HANDLERS)
		set(UNPARSED_ARGS)
	endif()
	verify_project_default_arguments( 	NAME "${PROJECT_NAME}" 
										VERSION "${PROJECT_VERSION}"
										AUTHORS ${PROJECT_AUTHORS}
										${UNPARSED_ARGS})
										
	
	if(NOT PROJECT_ID)
		trace("Defaulting PROJECT_ID to ${PROJECT_NAME}")
		set(PROJECT_ID ${PROJECT_NAME})
	endif()
	
	if(NOT PROJECT_OUTPUT_NAME)
		set(PROJECT_OUTPUT_NAME ${PROJECT_ID})
	endif()
	
	
	may_build_project(MAY_BUILD_PROJECT ${PROJECT_ID} ${PROJECT_PLATFORMS})
	if(NOT MAY_BUILD_PROJECT)
		if(PROJECT_PLATFORMS)
			set(MSG_AMENDMENT " as it only builds on ${PROJECT_PLATFORMS}, or because it was excluded/not included in the build set")
		endif()
		prominent_info("Skipping cpp project ${PROJECT_ID}${MSG_AMENDMENT}")
		return()
	endif()
	
	# verify we have a compiler explicitly set
	set(SKIP_DUE_TO_MISSING_COMPILER NO)
	if(UNIX)
		if(B_GXX_COMPILER_VERISON STREQUAL NONE)
			set(SKIP_DUE_TO_MISSING_COMPILER YES)
		endif()
	elseif(WIN32)
		if(B_VCC_VERSION STREQUAL NONE)
			set(SKIP_DUE_TO_MISSING_COMPILER YES)
		endif()
	endif()
	if(SKIP_DUE_TO_MISSING_COMPILER)
		# this must be a warning as the default case should still be to configure
		# your includes/excludes accordingly
		warning("Skipping cpp project ${PROJECT_NAME} as no compiler was configured in this build set '${B_BUILD_SET_NAME}'")
		return()
	endif()
	
	
	# CONFIGURATION
	################
	# just configure if we know we will be built
	if(NOT B_CPP_CONFIGURED)
		include(configure_cpp)
		configure_cpp()
	endif()
	
	if(NOT PROJECT_VERSION)
		error("Project VERSION was not set")
	endif()
	
	if(NOT PROJECT_TYPE)
		error("Project TYPE was not set")
	endif()
	
	# sanitize prefix
	if("${PROJECT_LIBRARY_PREFIX}" STREQUAL NONE)
		set(PROJECT_LIBRARY_PREFIX "")
	endif()
	
	# FIGURE OUT TYPE
	##################
	if (${PROJECT_TYPE} MATCHES EXECUTABLE)
		set(IS_EXECUTABLE YES)
	elseif (${PROJECT_TYPE} MATCHES "STATIC|MODULE|SHARED")
		set(IS_LIBRARY YES)
	else()
		error("Project TYPE ${PROJECT_TYPE} is not supported")
	endif()
	
	# OBTAIN SOURCE FILES
	#####################
	if(NOT PROJECT_SOURCE_FILES)
		if(NOT PROJECT_SOURCE_DIRS)
			set(PROJECT_SOURCE_DIRS .)
		endif()
		find_files_recursive(PROJECT_SOURCE_FILES "${PROJECT_SOURCE_DIRS}" "${B_PROJECT_CPP_FILESPECS}" ${PROJECT_SOURCE_FILES_EXCLUDE})
	endif()
	
	
	if(NOT PROJECT_SOURCE_FILES)
		error("Did not find any source file, or no source file specified. Use the SOURCE_FILES or SOURCE_DIRS parameter")
	endif()
	
	# append resource files
	list(APPEND PROJECT_SOURCE_FILES ${PROJECT_RESOURCE_FILES})
	
	# on linux, this is the default, on windows it isn't if I remember correctly
	# TODO: verify this is required
	trace("Adding . as implicit include")
	list(APPEND PROJECT_INCLUDE_DIRS .)
	list(REMOVE_DUPLICATES PROJECT_INCLUDE_DIRS)
	
	# CONFIGURATION FILE
	####################
	# get major, minor, patch names and concatenated versions
	version_components(
						PROJECT_VERSION_MAJOR
						PROJECT_VERSION_MINOR
						PROJECT_VERSION_PATCH
						${PROJECT_VERSION}
						)
	
	string(REPLACE ";" ", " PROJECT_AUTHORS_COMA_SEPARATED "${PROJECT_AUTHORS}")
	configure_file(
					${B_CMAKE_TEMPLATE_DIR}/build_configuration.h
					${CMAKE_CURRENT_BINARY_DIR}/build_configuration.h
					)
	# make sure the header can be included
	list(APPEND PROJECT_INCLUDE_DIRS ${CMAKE_CURRENT_BINARY_DIR})
					
	
	# add our base-lib (if it exists)
	# The baselib is shared among all plugins and is full of usefullies that are 
	# not specific to anything.
	# NOTE: Actually, in the lowest level version of this file, there should be 
	# no automatic handling at all - everything should be explicit. Fixing this 
	# will come at some cost, for now its just not worth it ... .
	set(BASELIB_DIR ${CMAKE_SOURCE_DIR}/src/cpp/txbase)
	if(IS_DIRECTORY ${BASELIB_DIR})
		trace("Automatically using baselibrary which is shared among all cpp tools")
		list(APPEND PROJECT_LINK_LIBRARIES txbase)
		list(REMOVE_DUPLICATES PROJECT_LINK_LIBRARIES)
		
		trace("Automatically adding include directory for base-library at ${BASELIB_DIR}")
		list(APPEND PROJECT_INCLUDE_DIRS ${BASELIB_DIR})
		list(REMOVE_DUPLICATES PROJECT_INCLUDE_DIRS)
	endif()

	
	# DIRECTORY LEVEL CONFIGURATION
	################################
	# None currently ! We specify everything by target when we get here
	# It is possible though to set per-directory properties in code  outside
	# of this function.
	
	prominent_info("Configuring ${PROJECT_ID} (${PROJECT_TYPE})")
	
	# CREATE TARGET
	###############
	if (IS_EXECUTABLE)
		add_executable(${PROJECT_ID}
						${PROJECT_SOURCE_FILES})
	else()
		add_library(${PROJECT_ID}
							${PROJECT_TYPE}
							${PROJECT_SOURCE_FILES})
	endif()
	
	# TARGET LEVEL CONFIGURATION
	#############################
	# Per-target configuration allows to have very different configurations
	# even though they are located in the same directory
	# Should only run once
	
	# PRESET INCLUDE DIRECTORIES
	# --------------------------
	# Sanitize includes - they need to be absolute
	foreach(INCLUDE_DIR IN LISTS PROJECT_INCLUDE_DIRS)
		if(NOT IS_ABSOLUTE ${INCLUDE_DIR})
			get_filename_component(INCLUDE_DIR ${INCLUDE_DIR} ABSOLUTE)
		endif()
		list(APPEND ABSOLUTE_INCLUDE_DIRS ${INCLUDE_DIR})
	endforeach()
	append_to_target_property(${PROJECT_ID} INCLUDE_DIRECTORIES "${ABSOLUTE_INCLUDE_DIRS}" NO)
	
	
	# SDK CONFIGURATION
	###################
	# Set per-sdk library- and include directories
	
	set(COUNT 0)
	list(LENGTH PROJECT_SDKS SDKLEN)
	math(EXPR MODULO_RESULT "${SDKLEN} % 2")
	if(NOT MODULO_RESULT EQUAL 0)
		error("SDKS must be set in pairs of SDK_Name and its Version")
	endif()
	while(COUNT LESS SDKLEN)
		math(EXPR COUNTP1 "${COUNT} + 1")
		set(SDK_ARGS)
		list(GET PROJECT_SDKS ${COUNT} SDK_NAME)
		list(GET PROJECT_SDKS ${COUNTP1} SDK_VERSION)
		sdk_version_override(${SDK_NAME} ${SDK_VERSION} SDK_VERSION)
		
		# find specific or general platform root
		# --------------------------------------
		cpp_lib_path(SDK_ROOT_PATH ${SDK_NAME} ${SDK_VERSION} TYPE ROOT)
		if(NOT IS_DIRECTORY ${SDK_ROOT_PATH})
			set(SPECIFIC_SDK_ROOT_PATH ${SDK_ROOT_PATH})
			cpp_lib_path(SDK_ROOT_PATH ${SDK_NAME} ${SDK_VERSION} TYPE ROOT NO_COMPILER_ID)
			if(NOT IS_DIRECTORY ${SDK_ROOT_PATH})
				error("Didn't find sdk root path neither at ${SPECIFIC_SDK_ROOT_PATH} nor at ${SDK_ROOT_PATH}") 
			endif()
			set(SDK_ARGS NO_COMPILER_ID)
		endif()
		
		# prefer specific include dir
		cpp_lib_path(SDK_INCLUDE_DIR ${SDK_NAME} ${SDK_VERSION} TYPE INCLUDE ${SDK_ARGS})
		if(NOT IS_DIRECTORY ${SDK_INCLUDE_DIR})
			set(SPECIFIC_SDK_INCLUDE_DIR ${SDK_INCLUDE_DIR})
			cpp_lib_path(SDK_INCLUDE_DIR ${SDK_NAME} ${SDK_VERSION} TYPE GENERAL_INCLUDE ${SDK_ARGS})
			trace("Using general include dir at ${SDK_INCLUDE_DIR} as specific one at '${SPECIFIC_SDK_INCLUDE_DIR}' was not found")
		else()
			trace("Using specific include dir at ${SDK_INCLUDE_DIR}")
		endif()
		
		if(NOT IS_DIRECTORY ${SDK_INCLUDE_DIR})
			error("Didn't find include directory at '${SDK_INCLUDE_DIR}'")
		endif()
		
		# library dir
		cpp_lib_path(SDK_LIBRARY_DIR ${SDK_NAME} ${SDK_VERSION} TYPE LIBRARY ${SDK_ARGS})
		if(NOT IS_DIRECTORY ${SDK_LIBRARY_DIR})
			error("Library directory at '${SDK_LIBRARY_DIR}' could not be accessed")
		else()
			trace("Using library search path at '${SDK_LIBRARY_DIR}'")
		endif()
		
		append_to_target_property(${PROJECT_ID} INCLUDE_DIRECTORIES ${SDK_INCLUDE_DIR} NO)
		append_to_target_property(${PROJECT_ID} LINK_FLAGS "${B_LINK_DIR_FLAG}\"${SDK_LIBRARY_DIR}\"" YES)	
		
		# CALL THE HANDLER
		if (PROJECT_USE_SDK_HANDLERS)
			set(HANDLER_MODULE ${SDK_NAME}_sdk_handler)
			# from here, the handler takes the rest
			include(${HANDLER_MODULE} OPTIONAL)
		endif() # use handlers
		
		math(EXPR COUNT "${COUNT} + 2")
	endwhile()
	
	
	# LINK OPTIMIZATIONS IN RELEASE MODE
	#####################################
	# Specifically for linux
	if (${CMAKE_BUILD_TYPE} MATCHES Release AND UNIX AND NOT APPLE AND NOT ${PROJECT_TYPE} MATCHES STATIC)
		append_to_target_property(${PROJECT_ID} LINK_FLAGS "-Wl,--strip-all,-O2" YES)
	endif()
	
	
	target_link_libraries(${PROJECT_ID}
									${PROJECT_LINK_LIBRARIES})
	
	if(PROJECT_DEFINES)
		append_to_target_property(${PROJECT_ID} COMPILE_DEFINITIONS "${PROJECT_DEFINES}" NO)
	endif()
	
	set_target_properties(${PROJECT_ID} PROPERTIES
											OUTPUT_NAME 
													${PROJECT_OUTPUT_NAME}
											CLEAN_DIRECT_OUTPUT 1)
	
	if (DEFINED PROJECT_LIBRARY_PREFIX)
		set_target_properties(${PROJECT_ID} PROPERTIES
											PREFIX "${PROJECT_LIBRARY_PREFIX}")
	endif()
	if (DEFINED PROJECT_LIBRARY_SUFFIX)
		set_target_properties(${PROJECT_ID} PROPERTIES
											SUFFIX ${PROJECT_LIBRARY_SUFFIX})
	endif()
	
	
	# DEFINE OUTPUT DIRECTORY
	#########################
	# Assure the output of one project (with different settings) will not overwrite
	# the output of anotherone. The target name is used as key which must be globally unique
	
	# verify the output was actually set for or output type
	if(PROJECT_TYPE MATCHES EXECUTABLE)
		set(PROJECT_OUTPUT_TYPE RUNTIME)
	elseif(PROJECT_TYPE MATCHES STATIC)
		set(PROJECT_OUTPUT_TYPE ARCHIVE)
	elseif(PROJECT_TYPE MATCHES MODULE|SHARED)
		set(PROJECT_OUTPUT_TYPE LIBRARY)
	else()
		error("Unknown PROJECT_TYPE: ${PROJECT_TYPE}") 
	endif() # figure out output type
	
	string(TOLOWER ${PROJECT_TYPE} PROJECT_TYPE_LOWER)
	set_target_properties(${PROJECT_ID} PROPERTIES
										${PROJECT_OUTPUT_TYPE}_OUTPUT_DIRECTORY ${PROJECT_ID}/${PROJECT_TYPE_LOWER})
										
		
	# POST BUILD STEP
	##################
	# handle project output dir !
	if(PROJECT_OUTPUT_DIRECTORY AND NOT PROJECT_TYPE MATCHES STATIC)
		add_custom_command(
							TARGET ${PROJECT_ID}
							POST_BUILD
							COMMAND ${CMAKE_COMMAND} ARGS -E copy $<TARGET_FILE:${PROJECT_ID}> ${PROJECT_OUTPUT_DIRECTORY}/$<TARGET_FILE_NAME:${PROJECT_ID}>
							COMMENT "Copying output of ${PROJECT_ID} to output directory ${PROJECT_OUTPUT_DIRECTORY}"
							)
	endif()
	
	
	# DOXYGEN HANDLING
	###################
	if(PROJECT_DOXYFILE_IN)
		doxygen_project(
							NAME
								${PROJECT_NAME}
							ID
								${PROJECT_NAME}_doxygen
							PARENT_PROJECT
								${PROJECT_ID}
							VERSION
								${PROJECT_VERSION}
							DOXYFILE_IN
								${PROJECT_DOXYFILE_IN}
						)
	endif() #end handle doxygen
	
endfunction()
