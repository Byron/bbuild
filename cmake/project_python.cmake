# Module implementing python project handling, assumes base.cmake to be loaded

# CONFIGURATION VARIABLES
#########################
set(B_PROJECT_PYTHON_FILESPECS *.py)
set(B_PROJECT_PYTHON_OPTIONS)
set(B_PROJECT_PYTHON_SINGLE_ARGS
		NAME
		VERSION
		SPHINX_CONFIG_IN
		DOXYFILE_IN
		ROOT_PACKAGE
		)
		
set(B_PROJECT_PYTHON_MULTI_ARGS
		SOURCE_DIRS
		SOURCE_FILES_EXCLUDE
		AUTHORS
		SDKS
		DOXYGEN_SOURCE_FILES_EXCLUDE)
		
		
# ==============================================================================
# python_lib_path(
#			RESULT_VARIABLE LIB_NAME LIB_VERSION
#			TYPE
#				GENERAL_INCLUDE|INCLUDE|LIBRARY|BINARY|ROOT
#			[NO_COMPILER_ID]
#			)
# This is just a wrapper for sdk_lib_path(), which sets it up for python
# automatically. See sdk_lib_path() for reference.
# ==============================================================================
function(python_lib_path RESULT_VARIABLE LIB_NAME LIB_VERSION)
	set(TYPE_OPTIONS
			GENERAL_INCLUDE INCLUDE INCLUDE BINARY ROOT)
	sdk_lib_path(${RESULT_VARIABLE} ${LIB_NAME} ${LIB_VERSION} ${ARGN} 
					LANGUAGE python)
	set(${RESULT_VARIABLE} ${${RESULT_VARIABLE}} PARENT_SCOPE)
endfunction()
		

# ==============================================================================
# python_project(	NAME
#						name
#					VERSION
#						version
#					AUTHORS
#						name [...nameN]
#					ROOT_PACKAGE
#						package_name
#					SOURCE_DIRS
#						dir1 [...dirN]
#					SOURCE_FILES_EXCLUDE
#						regex1 [...regexN]
#					SPHINX_CONFIG_IN
#						path_to_conf.py|DEFAULT
#					DOXYFILE_IN
#						doxyfile_path|DEFAULT
#					DOXYGEN_SOURCE_FILES_EXCLUDE
#						regex [...regexN]
#					SDKS
#						sdk_name	version
#						[...sdk_nameN versionN]	
#
# NAME (required)
#	The name of the project
# VERSION (required)
#	The semantic version of the project
# AUTHORS (required)
#	a list of author names in the format "First [Middle] [Last] <localpoart@domainpart>
# ROOT_PACKAGE (mandatory)
#	The name of the top-level package which contains all other packages and modules.
#	It is assumed to have a corresponding top-level directory of the same name
#	which contains all files - its automatically added to the SOURCE_DIRS
#	of the project if it not set specifically.
# SOURCE_DIRS (optional)
#	A list of one or more directories that contain python files.
#	If unset, it will default to the current source directory
# SOURCE_FILES_EXCLUDE (optional)
#	A list of one or more regular expressions that will cause a matching source
#	file to be excluded from the project. Examples are sub-dir/package or .*maya.*.py.
# SPHINX_CONFIG_IN (optional)
#	Either a path to the conf.py file to use or DEFAULT, which will make use
#	of a default conf.py.
#	Currently, all sphinx source files are expected to be located in 
#	${CMAKE_CURRENT_SOURCE_DIR}/doc/sphinx_src
#	If unset, no sphinx documentation will be built.
# DOXYFILE_IN (optional)
#	If set, the given doxygen configuration file will be used to configure
#	doxygen. See project_doxygen for more information.
#	If set to DEFAULT, a doxyfile template for python projects will be used,
#	which will automatically build docs for all your source files.
# DOXYGEN_SOURCE_FILES_EXCLUDE (optional)
#	One or more regular expressions that will remove a given source file on match
#	to prevent them from being part of the documentation.
# SDKS sdk_name version (optional)
#	A list of additional sdks and their respective tools, quite identical to the
#	sdk mechanism used in the cpp_project function. The difference is that we 
#	only support the handler mechanism.
#	Sdk handler are automatically used, there is no need for additional
#	specification.
#	NOTE: Please see cpp_project() function for more information, to be found in
#	project_cpp.cmake. Be sure to read the passage about HANDLER_ARGUMENTS
#	
# ==============================================================================
function(python_project)
	cmake_parse_arguments(PROJECT 
							"${B_PROJECT_PYTHON_OPTIONS}"
							"${B_PROJECT_PYTHON_SINGLE_ARGS}"
							"${B_PROJECT_PYTHON_MULTI_ARGS}"
							${ARGN})
					
	# allow unparsed arguments if we use handlers
	set(UNPARSED_ARGS "${PROJECT_UNPARSED_ARGUMENTS}")
	if (PROJECT_SDKS)
		set(UNPARSED_ARGS)
	endif()
	verify_project_default_arguments( 	NAME "${PROJECT_NAME}" 
										VERSION "${PROJECT_VERSION}"
										AUTHORS ${PROJECT_AUTHORS}
										${UNPARSED_ARGS})
	
	if(NOT PROJECT_ROOT_PACKAGE)
		error("Please specify the projects ROOT_PACKAGE name")
	endif()
	
	if(NOT PROJECT_SOURCE_DIRS)
		set(PROJECT_SOURCE_DIRS ${PROJECT_ROOT_PACKAGE})
		trace("Defaulting SOURCE_DIRS to ${PROJECT_SOURCE_DIRS}")
	endif()

	# Might be something more unique later
	set(PROJECT_ID ${PROJECT_NAME})
	
	may_build_project(MAY_BUILD_PROJECT ${PROJECT_ID} ${PROJECT_PLATFORMS})
	if(NOT MAY_BUILD_PROJECT)
		prominent_info("Skipping python project ${PROJECT_ID}")
		return()
	endif()
	prominent_info("Configuring python project ${PROJECT_ID}")
	
	# ASSURE PYTHON INTERPRETERS
	############################
	# NOTE: this could also go into a configure_python module
	include(FindPythonInterp)
	find_package(PythonInterp)
	
	if(NOT PYTHONINTERP_FOUND)
		error("Did not find a single python interpreter in the system - cannot handle python project")
	endif()
	
	
	# OBTAIN SOURCE CODE
	####################
	find_files_recursive(PROJECT_SOURCE_FILES "${PROJECT_SOURCE_DIRS}" "${B_PROJECT_PYTHON_FILESPECS}" ${PROJECT_SOURCE_FILES_EXCLUDE})
	
	if(NOT PROJECT_SOURCE_FILES)
		error("Did not find any source files for python project ${PROJECT_NAME}")
	endif()
	

	# SETUP TARGET
	##############
	# TODO: do something useful actually !
	add_custom_target(
						${PROJECT_ID}
						SOURCES
							${PROJECT_SOURCE_FILES}
						COMMENT
							"NoOp for python project ${PROJECT_ID}"
					)
					
	# HANDLE SDKS
	###############
	# call handlers
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
		
		# CALL THE HANDLER
		set(HANDLER_MODULE ${SDK_NAME}_sdk_handler)
		# from here, the handler takes the rest
		include(${HANDLER_MODULE} OPTIONAL)
		
		math(EXPR COUNT "${COUNT} + 2")
	endwhile()
	
	# HANDLE SPHINX DOCS
	#####################
	# For now, its very specific to python so we don't put it into a separate project
	# to save use some boilerplate code.
	if(PROJECT_SPHINX_CONFIG_IN)
		set(SPHINX_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/doc/sphinx_src)
		sphinx_project(	
						NAME
							${PROJECT_NAME}
						VERSION
							${PROJECT_VERSION}
						AUTHORS
							${PROJECT_AUTHORS}
						SOURCE_DIR
							${SPHINX_SOURCE_DIR}
						CONFIG_IN
							${SPHINX_CONFIG_IN}
						)
	endif()# handle sphinx documentation
	
	
	# DOXYGEN DOCS
	##############
	if(PROJECT_DOXYFILE_IN)
		if(PROJECT_DOXYFILE_IN STREQUAL DEFAULT)
			set(PROJECT_DOXYFILE_IN ${B_CMAKE_TEMPLATE_DIR}/doxyfile.py.in)
			trace("Defaulting to python doxyfile at ${PROJECT_DOXYFILE_IN}")
		endif()
		
		# find the doxypy script
		set(DOXYPY_SCRIPT ${CMAKE_CURRENT_LIST_DIR}/../python/doxypy.py)
		if(NOT EXISTS ${DOXYPY_SCRIPT})
			error("Didn't find doxypy script at ${DOXYPY_SCRIPT}")
		endif()
		
		# make sure it doesn't try to parse rc files
		# NOTE: its bad that we hardcode this here, but we can't really 
		# get feedback from the pyside handler yet which generates them
		
		doxygen_project(
							NAME
								${PROJECT_NAME}_api	# rename it to be sure it gets its own folder
							ID
								${PROJECT_ID}_doxygen
							PARENT_PROJECT
								${PROJECT_ID}
							VERSION
								${PROJECT_VERSION}
							DOXYFILE_IN
								${PROJECT_DOXYFILE_IN}
							SOURCE_FILES_EXCLUDE
								${PROJECT_DOXYGEN_SOURCE_FILES_EXCLUDE}
								".*_(rc|ui)\\.py"
								".*/fixtures.*"
						)
	endif()
	

endfunction()
