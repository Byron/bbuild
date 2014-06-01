# Note: This version is required as it introduces the per-target INCLUDE_DIRECTORIES
# that we use to perform multiple builds with different sdk versions, which is
# desireable for maya builds for instance)
cmake_minimum_required(VERSION 2.8.8)


# POLICIES
###########
cmake_policy(SET CMP0000 NEW) 		# A minimum required CMake version must be specified.
cmake_policy(SET CMP0001 NEW)		# CMAKE_BACKWARDS_COMPATIBILITY should no longer be used.
cmake_policy(SET CMP0002 NEW)		# Logical target names must be globally unique.
cmake_policy(SET CMP0003 NEW)		# Libraries linked via full path no longer produce linker search paths. 
cmake_policy(SET CMP0004 NEW)		# Libraries linked may not have leading or trailing whitespace.
cmake_policy(SET CMP0005 NEW)		# Preprocessor definition values are now escaped automatically.
cmake_policy(SET CMP0006 NEW)		# Installing MACOSX_BUNDLE targets requires a BUNDLE DESTINATION.
cmake_policy(SET CMP0007 NEW)		# list command no longer ignores empty elements.
cmake_policy(SET CMP0008 NEW)		# Libraries linked by full-path must have a valid library file name.
cmake_policy(SET CMP0009 NEW)		# FILE GLOB_RECURSE calls should not follow symlinks by default - specify FOLLOW_SYMLINKS instead
cmake_policy(SET CMP0010 NEW)		# Bad variable reference syntax is an error.
cmake_policy(SET CMP0011 NEW)		# include() policy change don't affect includer
cmake_policy(SET CMP0012 NEW)		# if recognizes numbers and booleans and does not try to dereference them
cmake_policy(SET CMP0013 NEW)		# don't allow duplicate binary directories (which could cause overrides)
cmake_policy(SET CMP0014 NEW)		# don't allow directories without CMakeLists.txt file in add_directory() calls
cmake_policy(SET CMP0015 NEW)		# link_directories() treats paths relative to the source dir.
cmake_policy(SET CMP0016 NEW) 		# Prefer files from the CMake module directory when including from there.



# INCLUDES
#############
include(CMakeParseArguments)

include(build_set)

include(project_doxygen)
include(project_sphinx)
include(project_cpp)
include(project_cpp_maya)
include(project_python)


# GLOBAL CONFIGURATION VARIABLES
################################
# Some static variables, they are usually not changed
set(B_CMAKE_DOC_TARGET_NAME doc)

# Serves as main entry point to the build system - it will be called in the 
# moment base is imported - this must only happen once
# ------------------------------------------------------------------------------
function(_B_main)
	# SET DEFAULT DIRECTORIES
	##########################
	set(B_CMAKE_TEMPLATE_DIR ${CMAKE_CURRENT_LIST_DIR}/../../etc/templates 
			CACHE INTERNAL "directory with templates that are used for simple variable substitution")
	
	# PLATFORM
	############
	if(NOT B_PLATFORM_ID)
		warning("Defaulting B_PLATFORM_ID to noarch")
		set(B_PLATFORM_ID noarch
			CACHE INTERNAL "architecture id to help linking compatible libraries")
	endif()
			
	# BUILD SET
	############
	# A build set allows to further specify how to build things, and which ones
	# Set up global properties.
	set(CONFIG_SUBDIR "${CMAKE_SUBDIR}/config")
	set(ABS_CONFIG_SUBDIR ${CMAKE_CURRENT_SOURCE_DIR}/${CONFIG_SUBDIR})
	if(NOT B_BUILD_SET)
		file(GLOB CONFIGURATIONS RELATIVE ${ABS_CONFIG_SUBDIR} ${CONFIG_SUBDIR}/*.cmake)
		if(NOT CONFIGURATIONS)
			error("Please put at least one build set into the ${ABS_CONFIG_SUBDIR} directory")
		endif()
		string(REPLACE ";" ", " COMA_SEPARATED_CONFIGS "${CONFIGURATIONS}")
		info("Available build sets (excluding .cmake extensions): " "${COMA_SEPARATED_CONFIGS}")
		error("B_BUILD_SET is not specified - please choose one of the ones mentioned before")
	endif()
	
	list(APPEND CMAKE_MODULE_PATH ${ABS_CONFIG_SUBDIR})
	include(${B_BUILD_SET} OPTIONAL RESULT_VARIABLE BUILDSET_LOADED)
	if(NOT BUILDSET_LOADED)
		file(GLOB CONFIGURATIONS RELATIVE ${ABS_CONFIG_SUBDIR} ${CONFIG_SUBDIR}/*.cmake)
		string(REPLACE ";" ", " COMA_SEPARATED_CONFIGS "${CONFIGURATIONS}")
		info("Available build sets (excluding .cmake extensions): " "${COMA_SEPARATED_CONFIGS}")
		error("Buildset named ${B_BUILD_SET} could not be loaded - did you spell it correctly ?")
	endif()
	
	# CONFIGURATION
	###############
	# The global doc target that builds all documentation
	# It will be made dependent on the respective sub-targets which do the actual
	# build
	if(NOT TARGET ${B_CMAKE_DOC_TARGET_NAME})
		add_custom_target(${B_CMAKE_DOC_TARGET_NAME})
	endif()
endfunction()

# ==============================================================================
# Write YES or NO into RESULT_VARIABLE if the current generator is a mutli-configuration
# generator, therefore the build-type is handled by itself, as it contains multiple
# build types.
# ==============================================================================
function(is_multi_build_type_generator RESULT_VARIABLE)
	if(CMAKE_GENERATOR MATCHES [Mm]ake)
		set(${RESULT_VARIABLE} NO PARENT_SCOPE)
	else()
		# for now, just assume non-makefiles handle multiple configurations.
		# its probably not true
		set(${RESULT_VARIABLE} YES PARENT_SCOPE)
	endif()
endfunction()

# ==============================================================================
# Trace the given variable if B_TRACE is enabled
# VARIABLE_NAME literal name of the parent scope variable to trace
# Additional arguments will prefix the text
# ==============================================================================
function(trace_var VARIABLE_NAME)
	if(B_TRACE)
		message(STATUS "--> ${ARGN} ${VARIABLE_NAME} = ${${VARIABLE_NAME}}")
	endif()
endfunction()

# ==============================================================================
# Trace all provided arguments if B_TRACE is set
# ==============================================================================
function(trace)
	if(B_TRACE)
		message(STATUS --> ${ARGN})
	endif()
endfunction()


# ==============================================================================
# Print the error message(s) in ARGN and abort the whole build process
# ==============================================================================
function(error)
	message(FATAL_ERROR ${ARGN})
endfunction()

# ==============================================================================
# Print the warning message(s) in ARGN, but proceed the build process
# ==============================================================================
function(warning)
	message(WARNING ${ARGN})
endfunction()

# ==============================================================================
# Print the info message(s) in ARGN and abort the whole build process
# ==============================================================================
function(info)
	message(STATUS ${ARGN})
endfunction()

# ==============================================================================
# Print a prominent info message from all arguments - its must like a headline
# ==============================================================================
function(prominent_info)
	message(STATUS "#### " ${ARGN} " ####")
endfunction()

# ==============================================================================
# Retrieve the major, minor and patch components of an input version string
# formated like major.minor.patch
# ==============================================================================
function(version_components OUT_MAJOR OUT_MINOR OUT_PATCH VERSION_STRING)
	set(REGEX "^[0-9]\\.[0-9]\\.[0-9](-[a-z]+)?$")
	if (NOT VERSION_STRING MATCHES ${REGEX})
		error("Invalid version encountered: '${VERSION_STRING}' - should match ${REGEX}")
	endif()
	
	string(REPLACE "." ";" COMPONENTS ${VERSION_STRING})
	list(LENGTH COMPONENTS NUM_COMPONENTS)
	
	if(NUM_COMPONENTS LESS 3)
		error("Invalid version string - need 3 components: ${VERSION_STRING}")
	endif()
	if(NUM_COMPONENTS GREATER 3)
		warning("possibly invalid version enountered: ${VERSION_STRING}")
	endif()
	
	list(GET COMPONENTS 0 MAJOR)
	list(GET COMPONENTS 1 MINOR)
	
	# TODO: make sure we separate the patch version from the -prerelease version info
	list(GET COMPONENTS 2 PATCH)
	
	set(${OUT_MAJOR} ${MAJOR} PARENT_SCOPE)
	set(${OUT_MINOR} ${MINOR} PARENT_SCOPE)
	set(${OUT_PATCH} ${PATCH} PARENT_SCOPE)
endfunction()

# ==============================================================================
# setup_file_transfer(RESULT_VARIABLE DESTINATION_DIRECTORY <SOURCE> [...<SOURCE>]
#
# Setup the SOURCE files in ARGN such that they will be copied over to the 
# DESTINATION_DIRECTORY whenever the SOURCE file changes.
# 	If their path is relative, it will be assumed relative to CMAKE_CURRENT_SOURCE_DIR
# DESTINATION_DIRECTORY will be created including its parents if it doesn't exist.
# 	The absolute resource destination paths will be placed into the RESULT_VARIABLE
# 	as list.
# 	Use this list as part of your source files specifications for targets to recreate them
# 	every time.
# ==============================================================================
function(setup_file_transfer RESULT_VARIABLE DESTINATION_DIRECTORY)
	#setup command arguments
	if(ARGC EQUAL 0)
		error("No resource files specified")
	endif()
	
	# make sure dest-dir exists
	if(NOT IS_DIRECTORY ${DESTINATION_DIRECTORY})
		trace("Creating non-existing destination directory: ${DESTINATION_DIRECTORY}")
		file(MAKE_DIRECTORY ${DESTINATION_DIRECTORY})
	endif()
	
	foreach(SOURCE_FILE IN LISTS ARGN)
		if(NOT IS_ABSOLUTE ${SOURCE_FILE})
			set(SOURCE_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${SOURCE_FILE})
		endif()
		if(IS_DIRECTORY ${SOURCE_FILE})
			error("Source file ${SOURCE_FILE} was a directory")
		endif()
		if(NOT EXISTS ${SOURCE_FILE})
			error("Source file ${SOURCE_FILE} did not exist")
		endif()
		get_filename_component(SOURCE_FILE_NAME ${SOURCE_FILE} NAME)
		
		set(DESTINATION_FILE ${DESTINATION_DIRECTORY}/${SOURCE_FILE_NAME})
		
		list(APPEND OUTPUT_LIST ${DESTINATION_FILE})
		list(APPEND COMMAND_ARGS COMMAND ${CMAKE_COMMAND} ARGS -E copy ${SOURCE_FILE} ${DESTINATION_FILE})
	endforeach() # for each resource file
	
	# build the actual command
	# Unfortunately we only have one comment.
	# Maybe we just do one command per source file ... shouldn't make.
	add_custom_command(
						OUTPUT ${OUTPUT_LIST}
						${COMMAND_ARGS}
						COMMENT "Copying source file to ${DESTINATION_DIRECTORY}"
						)
		
	# make sure the system considers them generated
	set_source_files_properties(${OUTPUT_LIST} PROPERTIES GENERATED 1)
	
	set(${RESULT_VARIABLE} ${OUTPUT_LIST} PARENT_SCOPE)
endfunction()


# ==============================================================================
# search the list with the given regex and return the first index that matched.
# RESULT_VARIABLE will be the index of the regex in the list which matched. Otherwise
#	its -1
# REGEX_LIST_VARIABLE variable in the parent scope holding the list of regexes that
#	should be searched.
# ITEM to match against regexes in list
# ==============================================================================
function(regex_list_matches RESULT_VARIABLE REGEX_LIST_VARIABLE ITEM)
	set(COUNT 0)
	foreach(REGEX IN LISTS ${REGEX_LIST_VARIABLE})
		if(${ITEM} MATCHES ${REGEX})
			set(${RESULT_VARIABLE} ${COUNT} PARENT_SCOPE)
			return()
		endif()
		math(EXPR COUNT "${COUNT} + 1")
	endforeach()
	set(${RESULT_VARIABLE} -1 PARENT_SCOPE)
endfunction()

# ==============================================================================
# Set the RESULT_VARIABLE to the current platform id, which is the value of
# B_PLATFORM_ID
# RESULT_VARIABLE will carry the platform id
# NOTE: previously this function actually deterimed the platform id procedurally
# but this was given up for more flexibility
# ==============================================================================
function(platform_id RESULT_VARIABLE)
	set(${RESULT_VARIABLE} ${B_PLATFORM_ID} PARENT_SCOPE)
endfunction()


# ==============================================================================
# lib_path(
#			RESULT_VARIABLE LANGUAGE LIB_NAME LIB_VERSION
#			(TYPE=)GENERAL_INCLUDE|INCLUDE|LIBRARY|BINARY|ROOT
#		   )
# Write a path at which all files related to LIB_NAME@LIB_VERSION can be found 
# for the given programming language into RESULT_VARIABLE.
# RESULT_VARIABLE
#	Name of the variable into which the generated path will be written. Please note
#	that it is not verified for existence, the logic has to be implemented by you.
# LANGUAGE
#	The programming language your lib_path should be generated for. Valid values
#	are: cpp, python
# LIB_NAME
#	Name of the library you would like to use, e.g. boost or mayasdk.
# LIB_VERSION
#	A version string identifying the version of the library, e.g. 6.3v2 or 2012
# ==============================================================================
function(lib_path RESULT_VARIABLE LANGUAGE LIB_NAME LIB_VERSION)
	set(${RESULT_VARIABLE} ${CMAKE_SOURCE_DIR}/lib/${LANGUAGE}/${LIB_NAME}/${LIB_VERSION} PARENT_SCOPE)
endfunction()

# ==============================================================================
# sdk_lib_path(
#			RESULT_VARIABLE LIB_NAME LIB_VERSION
#			TYPE
#				GENERAL_INCLUDE|INCLUDE|LIBRARY|BINARY|ROOT
#			LANGUAGE
#				language_id
#			[NO_COMPILER_ID]
#			)
# Write a path of the given TYPE for the given language's library
# RESULT_VARIABLE
#	Name of the variable into which the generated path will be written. Please note
#	that it is not verified for existence, the logic has to be implemented by you.
# LIB_NAME
#	Name of the library you would like to use, e.g. boost or mayasdk.
# LIB_VERSION
#	A version string identifying the version of the library, e.g. 6.3v2 or 2012
# TYPE may take any of the following values
# 	GENERAL_INCLUDE
#		(cpp only): An include directory which is platform-independent.
#		When setting up sdks, try to place platform independent includes at locations
#		which match the one you receive with this flag to reduce redundancy.
#		Most sdks should allow the usage of general includes.
#	INCLUDE
#		A platform specific include directory for cpp projects
#	LIBRARY
#		A platform specific directory which contains libraries to link against
#	BINARY
#		A platform specific directory containing binaries.
#	ROOT
#		The platform specific root directory which may contain any amount of
#		sub-directories.
# LANGUAGE (mandatory)
#	The name of the language the sdk can be found in, i.e. python, or cpp.
#	It corresponds to the respective path on disk
# NO_COMPILER_ID
#	If set as option, there will be no compiler appended to the paths.
#	This is relevant for all platform dependent libraries.
#	Please note that you should always prefer the most specific paths.
# ==============================================================================
function(sdk_lib_path RESULT_VARIABLE LIB_NAME LIB_VERSION)
	set(TYPE_OPTIONS 
			GENERAL_INCLUDE INCLUDE INCLUDE BINARY ROOT)
	cmake_parse_arguments(MY "NO_COMPILER_ID" "TYPE;LANGUAGE" "" ${ARGN})
	if(MY_UNPARSED_ARGUMENTS)
		error("Some arguments were not understood: ${MY_UNPARSED_ARGUMENTS}")
	endif()
	
	if(NOT MY_TYPE)
		error("Please specify a TYPE of path that you need")
	endif()
	
	if(NOT MY_LANGUAGE)
		error("Please specify a LANGUAGE the sdk can be used in")
	endif()

	lib_path(ROOT_PATH ${MY_LANGUAGE} ${LIB_NAME} ${LIB_VERSION})
	platform_id(PLATFORM_ID)
	
	if(NOT  MY_NO_COMPILER_ID)
		cpp_compiler_id(COMPILER_ID)
		set(COMPILER_ID _${COMPILER_ID})
	endif()
	
	set(ROOT_PATH_PLATFORM ${ROOT_PATH}/${PLATFORM_ID}${COMPILER_ID})
	if(${MY_TYPE} MATCHES GENERAL_INCLUDE)
		set(OUT_PATH ${ROOT_PATH}/include)
	elseif(${MY_TYPE} MATCHES INCLUDE)
		set(OUT_PATH ${ROOT_PATH_PLATFORM}/include)
	elseif(${MY_TYPE} MATCHES LIBRARY)
		set(OUT_PATH ${ROOT_PATH_PLATFORM}/lib)
	elseif(${MY_TYPE} MATCHES BINARY)
		set(OUT_PATH ${ROOT_PATH_PLATFORM}/bin)
	elseif(${MY_TYPE} MATCHES ROOT)
		set(OUT_PATH ${ROOT_PATH_PLATFORM})
	else()
		error("Please specify at least one TYPE option - possible values are: ${TYPE_OPTIONS}")
	endif()
	set(${RESULT_VARIABLE} ${OUT_PATH} PARENT_SCOPE)
endfunction()


# ==============================================================================
# find_files_recursive(RESULT_VARIABLE DIRECTORIES GLOBS [<exclude_regex> ...exclude_regexN]
#
# Set RESULT_VARIABLE to a list of file paths relative to the given list of DIRECTORIES
# which should be a relative path. All paths are based on the current source directory.
# All shown file paths will match one or more GLOBS like *.cpp or *.py
#
# RESULT_VARIABLE receives a list of files that matched GLOBS
# DIRECTORIES a list of absolute or relative directories to search files in
# GLOBS a list of file globs to match the files against
# ARGN All additional arguments will be interpreted as regular expressions which
# 	identify files to exclude.
# ==============================================================================
function(find_files_recursive RESULT_VARIABLE DIRECTORIES GLOBS)
	if(NOT GLOBS)
		error("GLOBS was empty")
	endif()
	foreach(SUBDIR ${DIRECTORIES})
		get_filename_component(ABSOLUTE_SUBDIR ${SUBDIR} ABSOLUTE)
		if(NOT EXISTS ${ABSOLUTE_SUBDIR})
			message(WARNING "In project ${PROJECT_ID}: source directory '${SUBDIR}' did not exist at ${ABSOLUTE_SUBDIR}. Please check your cmake configuration")
		endif()
		
		set(FILEGLOBS)
		foreach(FILESPEC ${GLOBS})
			list(APPEND FILEGLOBS ${SUBDIR}/${FILESPEC})
		endforeach()
		file(GLOB_RECURSE SOURCE_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} ${FILEGLOBS})
		list(APPEND ALL_SOURCE_FILES ${SOURCE_FILES})
	endforeach()
	
	# Finally, perform the filtering
	# NOTE: its somewhat inefficient as we parse everything, but prune afterwards.
	# Its the most general implementation though and shouldn't cause issues
	if(ARGN)
		filter_list_by_regex(ALL_SOURCE_FILES "${ALL_SOURCE_FILES}" "${ARGN}")
	endif()# IF ARGN 
	set(${RESULT_VARIABLE} ${ALL_SOURCE_FILES} PARENT_SCOPE)
endfunction()


# ==============================================================================
# filter_list_by_regex(RESULT_VARIABLE ITEM_LIST FILTER_REGEX)
#
# Remove all items in ITEM_LIST which match in at least one FILTER_REGEX and output
# the remainder in RESULT_VARIABLE
#
# ITEM_LIST is a list of files, to be passed as "LIST"
# FILTER_REGEX is a list of regular expressions, to be passed as "LIST"
# ==============================================================================
function(filter_list_by_regex RESULT_VARIABLE ITEM_LIST FILTER_REGEX)
	foreach(ITEM IN LISTS ITEM_LIST)
		set(IS_INCLUDED YES)
		foreach(EXCLUDE_REGEX IN LISTS FILTER_REGEX)
			if(${ITEM} MATCHES ${EXCLUDE_REGEX})
				set(IS_INCLUDED NO)
				trace("Excluding ${ITEM} as it matched ${EXCLUDE_REGEX}")
				break()
			endif()
		endforeach() # EXCLUDE REGEX
		if(IS_INCLUDED)
			list(APPEND ALL_ITEMS_FILTERED ${ITEM})
		endif()
	endforeach() # FILEPATH
	set(${RESULT_VARIABLE} ${ALL_ITEMS_FILTERED} PARENT_SCOPE)
endfunction()

# ==============================================================================
# prettyfied_name(RESULT_VARIABLE NAME)
#
# Write a pretty (gui) version of NAME into RESULT_VARIABLE
# It will replace underscores with spaces and capitalize the parts of the word
# ==============================================================================
function(prettyfied_name RESULT_VARIABLE NAME)
	string(REPLACE "_" ";" NAME_TOKENS ${NAME})
	# TODO: capitalization (maybe always, maybe optional)
	string(REPLACE ";" " " PRETTY_NAME "${NAME_TOKENS}")
	set(${RESULT_VARIABLE} ${PRETTY_NAME} PARENT_SCOPE)
endfunction()

# ==============================================================================
# Set any property on target level instead of on directory level.
# TARGET is the target name as used in add_executable() and relatives
# PROPERTY the target level property name
# VALUES is a semicolon separated list of values to set
# SPACE_SEPARATED if set, there will be a space betweeen the existing and the new
# 	value(s). Otherwise it will just be treated as a normal cmake list.
# ==============================================================================
function(append_to_target_property TARGET PROPERTY VALUES SPACE_SEPARATED)
	get_target_property(CURR_VALUES ${TARGET} ${PROPERTY})
	if (CURR_VALUES)
		if(SPACE_SEPARATED)
			set(CURR_VALUES "${CURR_VALUES} ${VALUES}")
		else()
			list(APPEND CURR_VALUES ${VALUES})
		endif()
	else()
		set(CURR_VALUES ${VALUES})
	endif()
	set_target_properties(${TARGET} PROPERTIES ${PROPERTY} "${CURR_VALUES}")
endfunction()


# ==============================================================================
# Find the given directory or file upwards from the given root directory, iterating
# a maximum of MAX_DEPTH. 3 would mean that 3 parent directories will be checked.
# The parent directory containing the sibling that was encountrerd first will be 
# put into RESULT_VARIABLE if the search was successful. Otherwise it will not be set.
# ==============================================================================
function(find_parent_directory_by_sibling RESULT_VARIABLE ROOT_DIR SIBLING_DIR MAX_DEPTH)
	set(DEPTH 0)
	while(DEPTH LESS MAX_DEPTH)
		get_filename_component(ROOT_DIR ${ROOT_DIR} PATH)
		set(SIBLING_PATH ${ROOT_DIR}/${SIBLING_DIR})
		if(EXISTS ${SIBLING_PATH})
			set(${RESULT_VARIABLE} ${ROOT_DIR} PARENT_SCOPE)
			return()
		endif()
		math(EXPR DEPTH "${DEPTH} + 1")
	endwhile()
endfunction()

# Internally used to make a glob absolute to the given directory
# The GLOB_VARIABLE will be changed if necessary
# ------------------------------------------------------
function(_to_absolute_glob BASEDIR GLOB_VARIABLE)
	# string(REGEX MATCH / SLASH_FOUND ${${GLOB_VARIABLE}})
	if(NOT IS_ABSOLUTE ${${GLOB_VARIABLE}})
		set(${GLOB_VARIABLE} ${BASEDIR}/${${GLOB_VARIABLE}} PARENT_SCOPE)
	endif()
endfunction()

# Internal method to recursively add subdirectories, skipping onces without
# a cmakelists file
# BASEDIR
#	directory at which to start the search
# DEPTH
#	Intial depth of the search - should be 0 if you make the call
# MAX_DEPTH
#	Maximium depth level. If it is 1, you would receive just the children of
#	your directory.
# ------------------------------------------------------------------------------
function(_add_subdir_globbed BASEDIR GLOBS DEPTH MAX_DEPTH)
	if(NOT DEPTH LESS MAX_DEPTH)
		return()
	endif()
	math(EXPR DEPTH "${DEPTH} + 1")
	
	foreach(GLOB IN LISTS GLOBS)
		_to_absolute_glob(${BASEDIR} GLOB)
		file(GLOB GLOB_RESULT ${GLOB})
		
		foreach(SUBDIR IN LISTS GLOB_RESULT)
			set(BINARY_DIR)
			if(B_BUILD_DIR)
				# cmake_build_type migth not be set - resulting path is still
				# correct though
				file(RELATIVE_PATH SUBDIR_NAME ${CMAKE_SOURCE_DIR} ${SUBDIR})
				set(BINARY_DIR ${B_BUILD_DIR}/${CMAKE_BUILD_TYPE}_${CMAKE_SYSTEM}/${B_BUILD_SET_NAME}/${SUBDIR_NAME})
			endif()
			# verify cmakelists exists
			if (EXISTS ${SUBDIR}/CMakeLists.txt AND NOT IS_SYMLINK ${SUBDIR})
				trace("add_subdirectory ${SUBDIR} ${BINARY_DIR}")
				add_subdirectory(${SUBDIR} ${BINARY_DIR})
			endif()
			
			if(IS_DIRECTORY ${SUBDIR})
				_add_subdir_globbed(${SUBDIR} "${GLOBS}" ${DEPTH} ${MAX_DEPTH})
			endif()
		endforeach() # GLOB RESULT
	endforeach() # GLOB
endfunction()

# ==============================================================================
# Add subdirectories which match a list of globs using the
# add_subdirectory() cmake function
# [GLOBS [glob ...]]
# 	One ore more file globs which expand to subdirectories.
#	If no glob is set, use all subdirectories
# [MAX_DEPTH NUM]
#	Defines the number of subdirectories that should be searched
# 	for a CMakeLists.txt file.
# 	If unset, it will be set to 1
# ==============================================================================
function(add_subdirectories)
	cmake_parse_arguments(MY "" "MAX_DEPTH" "GLOB" ${ARGN})
	
	if(NOT MY_GLOB)
		set(MY_GLOB *)
	endif()
	
	if(NOT MY_MAX_DEPTH)
		set(MY_MAX_DEPTH 1)
	endif()
	
	if(MY_UNPARSED_ARGUMENTS)
		message(FATAL_ERROR "Could not parse arguments: ${MY_UNPARSED_ARGUMENTS}")
	endif()
	
	_add_subdir_globbed(${CMAKE_CURRENT_SOURCE_DIR} "${MY_GLOB}" 0 ${MY_MAX_DEPTH})
endfunction()


# ==============================================================================
# Verify the given default arguments for any projects are set and valid
# If not, an error will be raised.
# Call this method without your unparsed arguments like so (the "" are required !)
# verify_project_default_arguments(	NAME "${MY_NAME}"
#									VERSION "${MY_VERSION}" 
#									AUTHORS ${MY_AUTHORS}
#									${MY_UNPARSED_ARGUMENTS}
#								   )
# NAME name
# 	Then name of the project, which must be set
# VERSION version
# 	A semantic version, see http://semver.org/
#	e.g. 0.1.0 or 0.1.2-devel
# AUTHORS author [...authorN]
# 	One or more authors in the format "First [Middle] [Last] <localpoart@domainpart>"
#
# NOTE: currently not the complete semver spec is supported, its a matter of 
# the regex though.
# ==============================================================================
function(verify_project_default_arguments)
	cmake_parse_arguments(PROJECT "" "NAME;VERSION" "AUTHORS" ${ARGN})
	
	if(PROJECT_UNPARSED_ARGUMENTS)
		error("Could not parse all arguments: ${PROJECT_UNPARSED_ARGUMENTS}")
	endif()

	if(NOT PROJECT_NAME)
		error("Please specify a project NAME")
	endif()
	
	if(NOT PROJECT_VERSION)
		error("Please specify a project VERSION")
	endif()
	
	# will raise if it cannot handle it
	version_components(
						PROJECT_VERSION_MAJOR
						PROJECT_VERSION_MINOR
						PROJECT_VERSION_PATCH
						${PROJECT_VERSION}
					   )
	
	if(NOT PROJECT_AUTHORS)
		error("You must specify at least one author in the format: 'first [middle] [last] <localpart@domain>'")
	endif()
	
	foreach(AUTHOR IN LISTS PROJECT_AUTHORS)
		set(REGEX "^([a-zA-Z\\-]+ )+<[a-zA-Z\\.]+@[a-zA-Z\\.\\-]+>$")
		if(NOT AUTHOR MATCHES ${REGEX})
			error("Invalid author format: '${AUTHOR}' - should be 'First Last <email@server.domain>'")
		endif()
	endforeach()
	
	# okay, everything is good
endfunction()


# ==============================================================================
# check_execution(			EXECUTABLE executable [arg1 [...argN]]
#							RESULT_VARIABLE variable 
#							[OUTPUT_VARIABLE variable] )
# Similar to execute_process, but simplifies checking if the execution of 
# an executable has the expected results
#
# EXECUTABLE (required)
#	the program to run as relative or absolute path
#	and its optional additional arguments.
# OUTPUT_VARIABLE (optional)
#	if given, contains the output standard output of the program.
#	It is only evaluated if the program could be found and executed
# RESULT_VARIABLE (required)
# 	store the result in this variable,  being a string tag:
#		NOT_FOUND  - the executable couldn't be found - only used on absolute paths
#		FAILED     - failed to run, i.e. return value was not 0.	
#		OK		   - the executable could be found and ran ok
# ==============================================================================
function(check_execution)
    cmake_parse_arguments(CHECK_EXEC "" "RESULT_VARIABLE;OUTPUT_VARIABLE" "EXECUTABLE;ARGS" ${ARGN})
    set(${RESULT_VARIABLE} NOT_FOUND PARENT_SCOPE)
    
    list(GET CHECK_EXEC_EXECUTABLE 0 EXECUTABLE) 
    if (IS_ABSOLUTE ${EXECUTABLE} AND NOT EXISTS ${EXECUTABLE})
    	return()
	endif()
	
	execute_process(  	COMMAND ${CHECK_EXEC_EXECUTABLE}
						RESULT_VARIABLE EXIT_CODE
						OUTPUT_VARIABLE STDOUT	)
    set(${CHECK_EXEC_OUTPUT_VARIABLE} "${STDOUT}" PARENT_SCOPE)
    
	if (${EXIT_CODE} EQUAL 0)
		set(${RESULT_VARIABLE} "OK" PARENT_SCOPE)
	else()
		set(${RESULT_VARIABLE} "FAILED" PARENT_SCOPE)
	endif()
endfunction()


# ==============================================================================
# Reads the given VERSION_FILE and matches all lines with FILE_REGEX, which 
# should attempt to match the version you seek, e.g. "[0-9]\\.[0-9]"
# The first line is then taken and matched against REPLACE_REGEX, which is supposed
# to isolate the version within the line. For this, you need a capture group
# within the regex, e.g. ".*(<your_version_regex).*".
# The isolated version will be written into the RESULT_VARIABLE
# NOTE: raises if the version file did not have any line with a version
# ==============================================================================
function(version_file_info RESULT_VARIABLE VERSION_FILE FILE_REGEX REPLACE_REGEX)
	file(STRINGS ${VERSION_FILE} VERSION_INFO REGEX ${FILE_REGEX})
	if (NOT VERSION_INFO)
		message(FATAL_ERROR "Could not find version information in file ${VERSION_FILE}")
	endif()
	string(REGEX REPLACE ${REPLACE_REGEX} "\\1" VERSION_INFO "${VERSION_INFO}")
	set(${RESULT_VARIABLE} ${VERSION_INFO} PARENT_SCOPE)
endfunction()



################################################################################
# Call entry point for first sanity checks
################################################################################
_B_main()
