

# CONFIGURATION VARIABLES
###########################
set(B_PROJECT_DOXYGEN_OPTIONS)
set(B_PROJECT_DOXYGEN_SINGLE_ARGS
			NAME
			ID
			PARENT_PROJECT
			DOXYFILE_IN
			OUTPUT_DIR
			VERSION
			)
set(B_PROJECT_DOXYGEN_MULTI_ARGS
			SOURCE_FILES_EXCLUDE)

# documentation target for all doxygen documentation
set(B_PROJECT_DOXYGEN_DOC_TARGET doc_doxygen)

# ==============================================================================
# doxygen_project(
#					NAME
#						name
#					ID
#						globally_unique_id
#					VERSION
#						version						
#					PARENT_PROJECT
#						target_name
#					SOURCE_FILES_EXCLUDE
#						regex [...regexN}
#					DOXYFILE_IN
#						doxyfile|DEFAULT
#					OUTPUT_DIR
#						directory
#
# Create a new doygen project with NAME which is generating documentation for all sources
# of its PARENT_PROJECT.
# All created doxygen targets will be bound to the 'doc_doxygen' target which can be used
# to generate all documentation at one. It in turn is bound to the 'doc' target, which 
# will produce all documentation.
# The doxygen target will be dependent on all its sources.
# 
# NAME
#	Name of the project - its just an identifier used for gui purposes.
# ID
#	A globally unique id serving as target for the project. It defaults to NAME.
# VERSION
#	The version of the documentation - usually the version of the parent project.
# PARENT_PROJECT
#	The name of the target of the parent project whose source files should be used.
#	They are supposed to be absolute or relative to the CMAKE_CURRENT_SOURCE_DIR.
# SOURCE_FILES_EXCLUDE (optional)
#	One or more regular expressions which are used to remove all matching source
#	files from the list of files to be documented.
# DOXYFILE_IN
#	A doxygen file which is based on the doyfile.in template.
#	It can contain any configuration, and replace any values
#	set in this function.
#	Doxygen is configured entirely through this file.
# 	See this this URL for more information: http://www.cmake.org/cmake/help/v2.8.8/cmake.html#command:configure_file.
#	It can have the built-in value DEFAULT, in which cause the default doxygen
#	template is used.
# OUTPUT_DIR (optional)
#	Directory to which all doxygen configuration will be written.
#	If unset, it will either default to ${B_DOC_DIR}/${NAME}/${VERSION}
#	or the ${CMAKE_CURRENT_BINARY_DIR}/doc if B_DOC_DIR is unset
# ==============================================================================
function(doxygen_project)
	cmake_parse_arguments(PROJECT
								"${B_PROJECT_DOXYGEN_OPTIONS}" 
								"${B_PROJECT_DOXYGEN_SINGLE_ARGS}" 
								"${B_PROJECT_DOXYGEN_MULTI_ARGS}"
								${ARGN})
	if(PROJECT_UNPARSED_ARGUMENTS)
		error("Did not parse all arguments: ${PROJECT_UNPARSED_ARGUMENTS}")
	endif()
	
	# VERIFY INPUT
	###############
	if(NOT PROJECT_NAME)
		error("A project NAME must be set")
	endif()
	
	if(NOT PROJECT_ID)
		trace("Defaulting doxygen PROJECT_ID to ${PROJECT_NAME}")
		set(PROJECT_ID ${PROJECT_NAME})
	endif()
	
	# bail out early if the target is already being made
	if(TARGET ${PROJECT_ID})
		trace("Skipping target ${PROJECT_ID} as it is already being created")
		return()
	endif()
	
	if(NOT PROJECT_VERSION)
		error("A VERSION must be set")
	endif()
	
	if(NOT PROJECT_PARENT_PROJECT)
		error("A PARENT_PROJECT must be set")
	endif()
	
	if(NOT TARGET ${PROJECT_PARENT_PROJECT})
		error("parent project ${PROJECT_PARENT_PROJECT} is not a target")
	endif()
	
	if(NOT PROJECT_DOXYFILE_IN)
		error("Require DOXYFILE_IN to be set")
	endif()
	
	if(${PROJECT_DOXYFILE_IN} STREQUAL DEFAULT)
		set(PROJECT_DOXYFILE_IN ${B_CMAKE_TEMPLATE_DIR}/doxyfile.in)
		trace("Using template doxyfile at ${PROJECT_DOXYFILE_IN}")
	endif() # set doxyfile template
	
	if(NOT EXISTS ${PROJECT_DOXYFILE_IN})
		error("Declared doxyfile at ${PROJECT_DOXYFILE_IN} was not accessible")
	endif()
	
	
	if(NOT PROJECT_OUTPUT_DIR)
		if(B_DOC_DIR)
			set(PROJECT_OUTPUT_DIR ${B_DOC_DIR}/${PROJECT_NAME}/${PROJECT_VERSION})
		else()
			set(PROJECT_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}/doc)
		endif()
		trace("Defaulting doxygen OUTPUT_DIR to ${PROJECT_OUTPUT_DIR}")
	endif()
	
	if(NOT IS_DIRECTORY ${PROJECT_OUTPUT_DIR})
		file(MAKE_DIRECTORY ${PROJECT_OUTPUT_DIR})
	endif()
	
	# DOXYGEN
	###########
	# Lets do this here, for now, to be able to share variables
	platform_id(PLATFORM_ID)
	FIND_PROGRAM(DOXYGEN_EXECUTABLE
			NAMES doxygen
			PATHS
			"${CMAKE_SOURCE_DIR}/3rdparty/doxygen/1.8.1.2/${PLATFORM_ID}/bin"
			NO_DEFAULT_PATH
			NO_CMAKE_ENVIRONMENT_PATH
			NO_CMAKE_PATH
			NO_SYSTEM_ENVIRONMENT_PATH
			NO_CMAKE_SYSTEM_PATH
			DOC "Doxygen documentation generation tool (http://www.doxygen.org)"
		)

	if(NOT DOXYGEN_EXECUTABLE)
		info("Skipping doxygen generation for project ${PROJECT_ID} for parent ${PROJECT_PARENT_PROJECT} as doxygen was not found")
		return()
	endif()
	
	# find dot - its still up to the doxyfile if it wants to and can use it
	FIND_PROGRAM(DOXYGEN_DOT_PATH
			NAMES dot
			DOC "dot graph visualization tool"
		)

	
	prominent_info("Setting up doxygen for ${PROJECT_NAME}")
	
	
	# PREPARE VARIABLES FOR REPLACEMENT
	##################################
	prettyfied_name(PROJECT_NAME_PRETTY ${PROJECT_NAME})
	set(DOXYFILE_PROJECT_NAME ${PROJECT_NAME_PRETTY})
	set(DOXYFILE_PROJECT_VERSION ${PROJECT_VERSION})
	set(DOXYFILE_HTML_DIR .)	# no html dir
	set(DOXYFILE_OUTPUT_DIR ${PROJECT_OUTPUT_DIR})
	get_target_property(DOXYFILE_SOURCE_DIRS ${PROJECT_PARENT_PROJECT} SOURCES)
	if(PROJECT_SOURCE_FILES_EXCLUDE)
		filter_list_by_regex(DOXYFILE_SOURCE_DIRS "${DOXYFILE_SOURCE_DIRS}" "${PROJECT_SOURCE_FILES_EXCLUDE}")
	endif()
	
	# assure we only add paths that actually exist - otherfile doxygen throws
	# a message that is just annoying by now.
	foreach(SOURCE_FILE IN LISTS DOXYFILE_SOURCE_DIRS)
		if(EXISTS ${SOURCE_FILE})
			list(APPEND DOXYFILE_SOURCE_DIRS_EXISTING ${SOURCE_FILE})
		endif()
	endforeach()
	set(DOXYFILE_SOURCE_DIRS ${DOXYFILE_SOURCE_DIRS_EXISTING})
	string(REPLACE ";" " " DOXYFILE_SOURCE_DIRS "${DOXYFILE_SOURCE_DIRS}")
	
	set(DOXYFILE ${CMAKE_CURRENT_BINARY_DIR}/Doxyfile_${PROJECT_PARENT_PROJECT})
	configure_file(${PROJECT_DOXYFILE_IN} ${DOXYFILE} @ONLY)
	
	set_property(DIRECTORY 
		APPEND PROPERTY
		ADDITIONAL_MAKE_CLEAN_FILES
		"${DOXYFILE_OUTPUT_DIR}/${DOXYFILE_HTML_DIR}")

	add_custom_target(
						${PROJECT_ID}
						COMMAND ${DOXYGEN_EXECUTABLE} ${DOXYFILE} 
						COMMENT "Writing doxygen documentation for ${PROJECT_NAME} at ${DOXYFILE_OUTPUT_DIR}..."
						WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
					)

	# Assure our doxygen doc target exists and is linked to the global target
	if(NOT TARGET ${B_PROJECT_DOXYGEN_DOC_TARGET})
		add_custom_target(${B_PROJECT_DOXYGEN_DOC_TARGET})
		add_dependencies(${B_CMAKE_DOC_TARGET_NAME} ${B_PROJECT_DOXYGEN_DOC_TARGET})
	endif()
	
	add_dependencies(${B_PROJECT_DOXYGEN_DOC_TARGET} ${PROJECT_ID})

endfunction()
