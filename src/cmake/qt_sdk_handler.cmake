################################################################################
# This handler supports the following arguments
# 
# QT_COMPONENTS [component_id [...componentIDN]]
# 	Name each component, like QtCore and QtGui that should be supported at runtime.
# 	This will affect the include directories of your project as well as the 
# 	libraries
################################################################################

set(B_SDK_HANDLER_QT_MULTI_ARGS QT_COMPONENTS)
# update our parsed arguments for subsequent handlers
set(B_PROJECT_CPP_MULTI_ARGS "${B_PROJECT_CPP_MULTI_ARGS};${B_SDK_HANDLER_QT_MULTI_ARGS}" PARENT_SCOPE)
cmake_parse_arguments(MY "" "" "${B_SDK_HANDLER_QT_MULTI_ARGS}" ${PROJECT_UNPARSED_ARGUMENTS})

###################
# FIND PROGRAMS ##
#################
# Make sure the persistent storage variables are removed - otherwise we don't get sdk changes !
unset(QT_MOC_EXECUTABLE CACHE)
unset(QT_RCC_EXECUTABLE CACHE)
unset(QT_UIC_EXECUTABLE CACHE)

if(NOT QT_MOC_EXECUTABLE)
	cpp_lib_path(QT_BINARY_DIR ${SDK_NAME} ${SDK_VERSION} TYPE BINARY)
	find_program(QT_MOC_EXECUTABLE
				NAMES moc-qt4 moc
				PATHS ${QT_BINARY_DIR}
				NO_DEFAULT_PATH
				)
	
	if(NOT QT_MOC_EXECUTABLE)
		message(FATAL_ERROR "Didn't find moc executable")
	endif()
	
	find_program(QT_UIC_EXECUTABLE
				NAMES uic-qt4 uic
				PATHS ${QT_BINARY_DIR}
				NO_DEFAULT_PATH
				)
	
	if(NOT QT_UIC_EXECUTABLE)
		message(FATAL_ERROR "Didn't find uic executable")
	endif()
	
	find_program(QT_RCC_EXECUTABLE 
				NAMES rcc
				PATHS ${QT_BINARY_DIR}
				NO_DEFAULT_PATH
				)

	if(NOT QT_RCC_EXECUTABLE)
		message(FATAL_ERROR "Didn't find rcc executable")
	endif()
endif()

set(QT_SDK_MAJOR_VERSION 3)
if(SDK_VERSION MATCHES "^4\\..*$")
	set(QT_SDK_MAJOR_VERSION 4)
endif()

# Generally we have to compile all output into a separate static library
# and link it into our top-level target. This makes sure all the items 
# are compiled first and available once the main item builds.
#########################################
# Handle Specific Include Directories ##
#######################################
# For qt3 this makes no sense, but doesn't harm either
set(QT_SOURCE_FILES)
if(MY_QT_COMPONENTS)
	cpp_lib_path(QT_INCLUDE_DIR ${SDK_NAME} ${SDK_VERSION} INCLUDE)
	foreach(COMPONENT IN LISTS MY_QT_COMPONENTS)
		include_directories(${QT_INCLUDE_DIR}/${COMPONENT})
	endforeach()
endif()

include(Qt4Macros)															# should also work for qt3

#################
# HANLDE MOCS ##
###############
# find all files which use the QOBJECT macro
# Use a relative path, so that the output goes to the binary dir automatically
# We assume that the include paths were already set
file(GLOB_RECURSE HEADER_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} "${CMAKE_CURRENT_SOURCE_DIR}/*.h")
foreach(HEADER_FILE IN LISTS HEADER_FILES)
	file(STRINGS ${HEADER_FILE} NEEDS_MOC REGEX "^.*Q_OBJECT.*$")
	if(NEEDS_MOC)
		get_filename_component(ABS_HEADER_FILE ${HEADER_FILE} ABSOLUTE) 
		qt4_make_output_file(${ABS_HEADER_FILE} moc_ cxx MOC_FILE)
		qt4_generate_moc(${ABS_HEADER_FILE} ${MOC_FILE})
		list(APPEND QT_SOURCE_FILES ${MOC_FILE})
	endif()
endforeach()


#######################
# Compile Resources ##
#####################
file(GLOB_RECURSE RESOURCE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*.qrc")
if(RESOURCE_FILES)
	qt4_add_resources(RESOURCE_OUT_FILES ${RESOURCE_FILES})
	set(QT_SOURCE_FILES "${QT_SOURCE_FILES};${RESOURCE_OUT_FILES}")
endif()


#############################
# Compile User Interfaces ##
###########################
file(GLOB_RECURSE UI_FILES "${CMAKE_CURRENT_SOURCE_DIR}/*.ui")
if(UI_FILES)
	# for now, use the default macro which just tosses everything into the 
	# binary directory. This is not so great as it could lead to name clashes.
	# if this happens, we will handle it
	include_directories(${CMAKE_CURRENT_BINARY_DIR})
	qt4_wrap_ui(UI_OUTFILES ${UI_FILES})
	set(QT_SOURCE_FILES "${QT_SOURCE_FILES};${UI_OUTFILES}")
endif()


# COMPILE ALL FILES INTO A SEPARATE TARGET
##########################################
if(QT_SOURCE_FILES)
	set(QT_ITEMS_LIBRARY_NAME qt_items_${PROJECT_OUTPUT_NAME})
	add_library(${QT_ITEMS_LIBRARY_NAME} STATIC ${QT_SOURCE_FILES})
	target_link_libraries(${PROJECT_OUTPUT_NAME} ${QT_ITEMS_LIBRARY_NAME})
	
	# as mocs include their source header, the definitions affecting it 
	# should affect the moc project as well. Otherwise we might get compile errors
	# due to missing or incorrect defines
	get_target_property(CURR_DEFINITIONS ${PROJECT_OUTPUT_NAME} COMPILE_DEFINITIONS)
	if(CURR_DEFINITIONS)
		_add_target_definitions(${QT_ITEMS_LIBRARY_NAME} "${CURR_DEFINITIONS}")
	endif()
endif()

# SETUP MODULE DEPENDENCY
#########################
# link in qt modules automatically
# on windows, qt4 libraries have a trailing 4 
set(LIB_TRAILER)
if(WIN32 AND QT_SDK_MAJOR_VERSION GREATER 3)
	# We rely on a macro which is expanded depending on the debug mode
	set(LIB_TRAILER $(d)${QT_SDK_MAJOR_VERSION})
endif()

# add each component
foreach(COMPONENT IN LISTS MY_QT_COMPONENTS)
	target_link_libraries(${PROJECT_OUTPUT_NAME} ${COMPONENT}${LIB_TRAILER})
endforeach()

