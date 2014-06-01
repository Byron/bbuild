# Module implementing any cpp project which uses Maya specifically
# It implements a convenience layer which allows to target multiple maya versions
# out of a single project specification.

# CONFIGURATION
################
set(B_PROJECT_CPP_MAYA_OPTIONS)
set(B_PROJECT_CPP_MAYA_SINGLE_ARGS 
		${B_PROJECT_CPP_SINGLE_ARGS})
set(B_PROJECT_CPP_MAYA_MULTI_ARGS
		${B_PROJECT_CPP_MULTI_ARGS}
		MAYA_VERSIONS
		LINK_LIBRARIES_MAYA
		)
	
# keeps track of variables that we deal with manually
set(B_PROJECT_MAYA_MANUALLY_HANDLED_VARIABLES
		ID
		SDKS
		LINK_LIBRARIES
		DEFINES
		MAYA_VERSIONS
		LINK_LIBRARIES_MAYA
		LIBRARY_SUFFIX
		OUTPUT_NAME
		LIBRARY_PREFIX
		OUTPUT_DIRECTORY
		RESOURCE_FILES)

		
# ==============================================================================
# maya_cpp_project(
#					<All args of cpp_project>
#					LINK_LIBRARIES_MAYA
#						libname [...libnameN]
# 
# This function wraps the cpp_project function and configures it to link in
# all relevant maya libraries and definitions for the currently set maya version.
# The maya version is determined by the version of the mayasdk set in B_SDK_OVERRIDES
# 
# You will have to specifiy
#	NAME and VERSION
#
# You MAY specify TYPE, which will default to MODULE.
#
# You MUST NOT specify LIBRARY_SUFFIX and LIBRARY_PREFIX if TYPE is MODULE, as it will set it up to 
# be suitable for a maya plug-in.
# In any other case, you may specify them or leave them to the system defaults.
#
# It will search for AENodeTemplates, python scripts and XPM files that will
# be copied automatically to the respective location in the B_MAYA_ENVIRONMENT_DIR
# 
# LINK_LIBRARIES_MAYA
#	Specifies one or more custom libraries that are compiled using this function
#	and that you would like to link against.
#	Specify the actual project name only, e.g. maya_base, and not maya_base_maya2012.
#	It will automatically be setup to contain the baselib for maya.
# ==============================================================================
function(maya_cpp_project)
	cmake_parse_arguments(PROJECT "${B_PROJECT_CPP_MAYA_OPTIONS}" "${B_PROJECT_CPP_MAYA_SINGLE_ARGS}" "${B_PROJECT_CPP_MAYA_MULTI_ARGS}" ${ARGN})
	
	if(PROJECT_UNPARSED_ARGUMENTS)
		error("Some arguments could not be parsed: ${PROJECT_UNPARSED_ARGUMENTS}")
	endif()
	
	
	# Check project
	if(NOT PROJECT_NAME)
		error("Please set a project NAME")
	endif()
	
	if(NOT PROJECT_TYPE)
		set(PROJECT_TYPE MODULE)
	elseif(${PROJECT_TYPE} MATCHES MODULE)
		error("Please don't specify TYPE MODULE as it is implied and done for you. You may specify any other TYPE though if required")
	endif()
	
	# CHECK IF WE MAY BUILD
	#########################
	may_build_project(MAY_BUILD_PROJECT ${PROJECT_NAME})
	if(NOT MAY_BUILD_PROJECT)
		prominent_info("Skipping maya cpp project ${PROJECT_NAME}")
		return()
	endif()
	
	sdk_version_override(mayasdk UNSET MAYA_SDK_VERSION)
	if(MAYA_SDK_VERSION STREQUAL UNSET)
		# We need at least a warning here as projects that are not configured
		# should be explicitly skipped by includes/excludes of the build-set
		prominent_info("Skipping maya project ${PROJECT_NAME} as the maya version was unset in build set '${B_BUILD_SET_NAME}'")
		return()
	endif()
	
	
	# only configure once we know we will be built
	# configuration
	if(NOT B_CPP_MAYA_CONFIGURED)
		include(configure_cpp_maya)
		configure_cpp_maya()
	endif()
	
	list(FIND PROJECT_SDKS mayasdk MAYASDK_INDEX)
	if(MAYASDK GREATER -1)
		error("mayasdk may not be specified explicitly, as its configured automatically using your MAYA_VERSIONS")
	endif()
	
	# LINK LIBRARIES DEFAULTS
	#########################
	find_parent_directory_by_sibling(MAYABASE_PARENT_DIR ${CMAKE_CURRENT_SOURCE_DIR} mayabaselib 1)
	if(IS_DIRECTORY ${MAYABASE_PARENT_DIR})
		trace("Adding maya_base to the list of maya libraries to use")
		list(APPEND PROJECT_LINK_LIBRARIES_MAYA cppmayabase)
		list(REMOVE_DUPLICATES PROJECT_LINK_LIBRARIES_MAYA)
		
		# INCLUDE DIR DEFAULTS
		######################
		trace("Adding ${MAYABASE_PARENT_DIR} as include directory to allow mayabaselib usage")
		list(APPEND PROJECT_INCLUDE_DIRS ${MAYABASE_PARENT_DIR})
		list(REMOVE_DUPLICATES PROJECT_INCLUDE_DIRS)
	endif()

	# CREATE BASIC ARGS
	#####################
	# These arguments are shared among all maya versions
	# DEFINES
	# -------
	if(UNIX)
		if(APPLE)
			list(APPEND MAYA_DEFINES OSMac_ OSMacOSX_ OSMac_MachO_)
		else()
			list(APPEND MAYA_DEFINES LINUX)
		endif()
	else()
		list(APPEND MAYA_DEFINES _AFXDLL _MBCS NT_PLUGIN)
	endif()
	list(APPEND BASE_ARGS DEFINES _BOOL REQUIRE_IOSTREAM ${MAYA_DEFINES} ${PROJECT_DEFINES})
	
	# LIBRARIES
	############
	# Just use all of them
	# we store the base set of libraries in a separate value as its being appended to later
	set(LINK_LIBRARIES_BASE
						Foundation
						OpenMaya
						OpenMayaAnim
						OpenMayaRender
						OpenMayaFX
						OpenMayaUI
						${PROJECT_LINK_LIBRARIES})
						
	# PREFIX/SUFFIX
	#################
	if(PROJECT_TYPE MATCHES MODULE)
		if(DEFINED PROJECT_LIBRARY_PREFIX OR DEFINED PROJECT_LIBRARY_SUFFIX)
			error("LIBRARY_PREFIX or LIBRARY_SUFFIX may not be specified if TYPE is MODULE as it will be set automatically")
		endif()
		
		# suffix
		if(WIN32)
			set(PROJECT_LIBRARY_SUFFIX .mll)
		elseif(APPLE)
			set(PROJECT_LIBRARY_SUFFIX .bundle)
		else()
			set(PROJECT_LIBRARY_SUFFIX .so)
		endif()

		# don't use the lib-prefix
		set(PROJECT_LIBRARY_PREFIX "NONE")
	endif()
	foreach(LIB_VAR LIBRARY_SUFFIX LIBRARY_PREFIX)
		if(DEFINED PROJECT_${LIB_VAR})
			list(APPEND BASE_ARGS ${LIB_VAR} "${PROJECT_${LIB_VAR}}")
		endif()
	endforeach()
	
	
	# OUTPUT NAME
	#############
	if(NOT PROJECT_OUTPUT_NAME)
		set(PROJECT_OUTPUT_NAME ${PROJECT_NAME})
	endif()
	list(APPEND BASE_ARGS OUTPUT_NAME ${PROJECT_OUTPUT_NAME})
	
	# OPTIONS
	##########
	foreach(OPTION_VAR ${B_PROJECT_CPP_MAYA_OPTIONS})
		if(PROJECT_${OPTION_VAR})
			list(APPEND BASE_ARGS ${OPTION_VAR} ${PROJECT_${OPTION_VAR}})
		endif() # option var is set
	endforeach()
	
	# SINGLE ARG OPTIONS
	####################
	foreach(SINGLE_ARG_VAR ${B_PROJECT_CPP_MAYA_SINGLE_ARGS})
		list(FIND B_PROJECT_MAYA_MANUALLY_HANDLED_VARIABLES ${SINGLE_ARG_VAR} SINGLE_ARG_VAR_INDEX)
		if(${SINGLE_ARG_VAR_INDEX} EQUAL -1 AND PROJECT_${SINGLE_ARG_VAR})
			list(APPEND BASE_ARGS ${SINGLE_ARG_VAR} ${PROJECT_${SINGLE_ARG_VAR}})
		endif() # handle variable as its not forbidden
	endforeach()
	
	# RESOURCE HANDLING
	#####################
	# Automatically trigger copying scripts and icons
	# First, find resources. 
	# NOTE: Mel scripts may only be AETemplates.
	# Everything else must be python scripts
	# TODO: use install() for this
	set(RESOURCE_EXTENSIONS *.xpm 	AE*Template.mel 		*.py)
	set(RESOURCE_RELA_DIRS 	icons 	scripts/AETemplates 	scripts/py)
	set(COUNT 0)
	foreach(RESOURCE_EXT IN LISTS RESOURCE_EXTENSIONS)
		list(GET RESOURCE_RELA_DIRS ${COUNT} RELA_DIR)
		math(EXPR COUNT "${COUNT} + 1")
		
		set(SOURCE_RESOURCE_FILES)
		find_files_recursive(SOURCE_RESOURCE_FILES . ${RESOURCE_EXT} ${PROJECT_SOURCE_FILES_EXCLUDE})
		
		if(SOURCE_RESOURCE_FILES)
			trace("Found ${RESOURCE_EXT} resources - setting up resource transfer")
			setup_file_transfer(DEST_RESOURCE_FILES ${B_MAYA_ENVIRONMENT_DIR}/${RELA_DIR} ${SOURCE_RESOURCE_FILES})
			list(APPEND ALL_RESOURCE_DESTINATION_FILES ${DEST_RESOURCE_FILES})
		endif()
	endforeach()# resource extension
	# allow the user to specify own destinations as well
	list(APPEND ALL_RESOURCE_DESTINATION_FILES ${PROJECT_RESOURCE_FILES})
	if(ALL_RESOURCE_DESTINATION_FILES)
		list(APPEND BASE_ARGS RESOURCE_FILES ${ALL_RESOURCE_DESTINATION_FILES})
	endif()

	
	# CREATE ONE PROJECT PER MAYA VERSION
	######################################
	# This requires the cpp project that we prepare to use per-target includes
	# and libraries
	set(ARGS "${BASE_ARGS}")					# reinitialize
	
	# LINK LIBRARIES
	#################
	list(APPEND ARGS LINK_LIBRARIES ${LINK_LIBRARIES_BASE})
	foreach(MAYA_LIBRARY IN LISTS PROJECT_LINK_LIBRARIES_MAYA)
		list(APPEND ARGS ${MAYA_LIBRARY}_maya${MAYA_SDK_VERSION})
	endforeach()
	
	set(PROJECT_ID ${PROJECT_NAME}_maya${MAYA_SDK_VERSION})
	
	list(APPEND ARGS ID ${PROJECT_ID})
	
	# for now, put the plugins for all platforms into the same directory.
	# this works as they have unique extensions on all platfoms: .bundle, .so, .mll
	# NOTE: For now we assume that we don't need per-linux-distro versions, if this should
	# be needed, we can add it here easily
	list(APPEND ARGS OUTPUT_DIRECTORY ${B_MAYA_ENVIRONMENT_DIR}/plug-ins/${MAYA_SDK_VERSION}/${B_PLATFORM_ID})
	
	# EXPLICITLY SETUP MAYA SDKk
	###########################
	# specify the current mayasdk version next to all additional sdks
	list(APPEND ARGS SDKS
					mayasdk ${MAYA_SDK_VERSION}
					${PROJECT_SDKS})
	
	# SETUP REMAINING VARIABLES
	############################
	# All variables which have not been handled manually should be put into the
	# argument stream automatically
	foreach(MULTI_ARG_VAR ${B_PROJECT_CPP_MAYA_MULTI_ARGS})
		list(FIND B_PROJECT_MAYA_MANUALLY_HANDLED_VARIABLES ${MULTI_ARG_VAR} MULTI_ARG_VAR_INDEX)
		if(${MULTI_ARG_VAR_INDEX} EQUAL -1 AND PROJECT_${MULTI_ARG_VAR})
			list(APPEND ARGS ${MULTI_ARG_VAR} ${PROJECT_${MULTI_ARG_VAR}})
		endif() # if multi-arg variable is not on the list
	endforeach()# for each mutli-argument
	
	# PROJECT CALL
	##############
	# finally, make the call that creates the respective cpp project
	# need "", otherwise empty args are ignored
	cpp_project("${ARGS}")
	
endfunction()
		


