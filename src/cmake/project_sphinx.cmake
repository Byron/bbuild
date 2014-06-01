

# CONFIGURATION VARIABLES
###########################
set(B_PROJECT_SPHINX_OPTIONS)
set(B_PROJECT_SPHINX_SINGLE_ARGS
			NAME
			ID
			SOURCE_DIR
			CONFIG_IN
			OUTPUT_DIR
			VERSION
			)
set(B_PROJECT_SPHINX_MULTI_ARGS
		AUTHORS)

# documentation target for all sphinx documentation
set(B_PROJECT_SPHINX_DOC_TARGET doc_sphinx)
set(B_PROJECT_SPHINX_SRC_FILESPECS *.rst)

# ==============================================================================
# sphinx_project(
#					NAME
#						name
#					ID
#						globally_unique_id
#					AUTHORS
#						name1 [...nameN]
#					VERSION
#						version
#					CONFIG_IN
#						conf.py|DEFAULT
#					SOURCE_DIR
#						dir
#					OUTPUT_DIR
#						directory
#
# Create a new sphinx project with NAME which is generating documentation for all
# rst files in 
# All created spihnx targets will be bound to the 'doc_sphinx' target which can be used
# to generate all documentation at one. It is in turn bound to the 'doc' target, 
# which can build all documentation.
# 
# NAME (required)
#	Name of the project - its just an identifier used for gui purposes. Usually
#	the name of the parent project.
# ID (optional)
#	A globally unique id serving as target for the project. It defaults to NAME.
# VERSION (required)
#	The version of the documentation - usually the version of a parent project.
# AUTHORS (required)
#	All authors who wrote the documentation in the form. The format is not further
#	specified, but would contain at least a first or last name.
# CONFIG_IN (optional)
# 	An optional relative or absolute path to the conf.py file of your project.
#	Your project name and project version will be substituted, as well as the authors.
#	Variables are: PROJECT_NAME, PROJECT_VERSION, PROJECT_AUTHORS.
#	The special built-in value DEFAULT will cause a default conf.py to be used
#	and substituted. It assumes that your manually written source is available
#	at ${CMAKE_CURRENT_SOURCE_DIR}/doc/sphinx
# SOURCE_DIR (required)
#	The directory containing the .rst files to be built. It can be relative to 
#	the CMAKE_CURRENT_SOURCE_DIR or absolute.
# OUTPUT_DIR (optional)
#	Directory to which all sphinx html will be written.
#	If unset, it will either default to ${B_DOC_DIR}/${NAME}/${VERSION}
#	or the ${CMAKE_CURRENT_BINARY_DIR}/doc if B_DOC_DIR is not set in the 
#	configuration of this build set.
# ==============================================================================
function(sphinx_project)
	cmake_parse_arguments(PROJECT
								"${B_PROJECT_SPHINX_OPTIONS}" 
								"${B_PROJECT_SPHINX_SINGLE_ARGS}" 
								"${B_PROJECT_SPHINX_MULTI_ARGS}"
								${ARGN})
	if(PROJECT_UNPARSED_ARGUMENTS)
		error("Did not parse all arguments: ${PROJECT_UNPARSED_ARGUMENTS}")
	endif()
	
	# VERIFY INPUT
	if(NOT PROJECT_NAME)
		error("Please specify a project NAME")
	endif()
	
	if(NOT PROJECT_VERSION)
		error("Please specify a project VERSION")
	endif()
	
	if(NOT PROJECT_AUTHORS)
		error("You must specify at least one author in the format: 'first [middle] [last] <localpart@domain>'")
	endif()
	
	if(NOT PROJECT_SOURCE_DIR)
		error("Please specify the SOURCE_DIR containing the ${B_PROJECT_SPHINX_SRC_FILESPECS} files")
	endif()
	
	
	# gracefully skip on missing sphinx
	find_package(Sphinx)
	if(NOT SPHINX_EXECUTABLE)
		prominent_info("Skipping sphinx compilation for project ${PROJECT_NAME} as sphinx executable was not found")
		return()
	endif()	

	
	# SET DEFAULTS
	##############
	if(NOT PROJECT_ID)
		set(PROJECT_ID ${PROJECT_NAME}_doc_sphinx)
	endif()
	
	# HTML output directory
	if(NOT PROJECT_OUTPUT_DIR)
		if(B_DOC_DIR)
			set(PROJECT_OUTPUT_DIR ${B_DOC_DIR}/${PROJECT_NAME}/${PROJECT_VERSION})
		else()
			set(PROJECT_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/doc)
		endif()
		trace("Defaulting PROJECT_OUTPUT_DIR to ${PROJECT_OUTPUT_DIR}")
	endif()
	
	if(NOT PROJECT_CONFIG_IN)
		set(PROJECT_CONFIG_IN DEFAULT)
	endif()
	
	# SPHINX CONFIGURATION
	#######################
	if(PROJECT_CONFIG_IN STREQUAL DEFAULT)
		set(PROJECT_CONFIG_IN ${B_CMAKE_TEMPLATE_DIR}/conf.py.in)
		trace("Using default conf.py at ${PROJECT_CONFIG_IN}")
	endif()
	
	if(NOT EXISTS ${PROJECT_CONFIG_IN})
		error("Sphinx configuration file '${PROJECT_CONFIG_IN}' is not accessible")
	endif()
	
	
	# find source files
	################
	# use a convention for now
	find_files_recursive(SPHINX_SOURCE_FILES "${PROJECT_SOURCE_DIR}" "${B_PROJECT_SPHINX_SRC_FILESPECS}")
	
	if(NOT SPHINX_SOURCE_FILES)
		error("Didn't find any ${B_PROJECT_SPHINX_SRC_FILESPECS} files in directory ${PROJECT_SOURCE_DIR}")
	endif()
	
	
	# PREPARE TARGET 
	################
	# configured documentation tools and intermediate build results
	set(SPHINX_BINARY_BUILD_DIR "${CMAKE_CURRENT_BINARY_DIR}/sphinx/${PROJECT_ID}/build")
	# Sphinx cache with pickled ReST documents
	set(SPHINX_CACHE_DIR "${CMAKE_CURRENT_BINARY_DIR}/sphinx/${PROJECT_ID}/doctrees")
	
	# PREPARE SUBSTITUTION VARIABLES
	#################################
	set(SPHINX_CONF_FILE ${SPHINX_BINARY_BUILD_DIR}/conf.py)
	prettyfied_name(PROJECT_NAME_PRETTY ${PROJECT_NAME})
	
	string(REPLACE ";" ", " PROJECT_AUTHORS_COMA_SEPARATED "${PROJECT_AUTHORS}")
	version_components(PROJECT_VERSION_MAJOR PROJECT_VERSION_MINOR PROJECT_VERSION_PATCH ${PROJECT_VERSION})
	configure_file(${PROJECT_CONFIG_IN} ${SPHINX_CONF_FILE} @ONLY)
	
	
	
	# SETUP TARGET
	##############
	if(NOT IS_DIRECTORY ${PROJECT_OUTPUT_DIR})
		file(MAKE_DIRECTORY ${PROJECT_OUTPUT_DIR})
	endif()
	
	add_custom_target(
		${PROJECT_ID}
		COMMAND ${SPHINX_EXECUTABLE}
			-q -b html
			-c "${SPHINX_BINARY_BUILD_DIR}"
			-d "${SPHINX_CACHE_DIR}"
			"${PROJECT_SOURCE_DIR}"
			"${PROJECT_OUTPUT_DIR}"
		COMMENT "Building sphinx documentation for ${PROJECT_NAME} to ${PROJECT_OUTPUT_DIR} ..."
		SOURCES ${SPHINX_SOURCE_FILES})
		
	trace("Added sphinx documentation target: ${PROJECT_ID}")
		
	# ASSURE OUR CUSTOM SPHINX TARGET EXISTS
	if(NOT TARGET ${B_PROJECT_SPHINX_DOC_TARGET})
		add_custom_target(${B_PROJECT_SPHINX_DOC_TARGET})
		add_dependencies(${B_CMAKE_DOC_TARGET_NAME} ${B_PROJECT_SPHINX_DOC_TARGET})
	endif()
	add_dependencies(${B_PROJECT_SPHINX_DOC_TARGET} ${PROJECT_ID})
	
endfunction()
