################################################################################
# This handler supports the following arguments:
# PYSIDE_UI_FILES file [...fileN]
#	relative paths to ui source files to be compiled by the pyside-uic tool
#
# It will perform the following operations
# COMPILE RESOURCE FILES
# #######################
# Find all *.qrc files and compile them to the respective python resource file.
# A file named gui/myresource.qrc will be compiled to gui/myresource_rc.py
# 
# COMPILE UI FILES
##################
# UI Files identified by their relative path in the PYSIDE_UI_FILES list 
# that should be compiled to python code.
# A file named mywidget.ui will end up as mywidget_ui.py .
# Please note that you may also load ui files directly, which might be preferred
# over tracking intermediate/compiled files in a mainline repository.
# (http://stackoverflow.com/questions/7144313/loading-qtdesigners-ui-files-in-pyside)
################################################################################

# Convert the given FILENAME so that path/input.ext becomes path/input_${SUFFIX}.ext
# and save the result in RESULT_VARIABLE
# ------------------------------------------------------------------------------
function(_pyside_convert_filename FILENAME SUFFIX RESULT_VARIABLE)
	string(REGEX REPLACE "(.*)\\..*" "\\1" DIR_AND_BASE ${FILENAME})
	set(${RESULT_VARIABLE} ${DIR_AND_BASE}_${SUFFIX}.py PARENT_SCOPE)
endfunction()

set(B_SDK_HANDLER_PYSIDE_MULTI_ARGS PYSIDE_UI_FILES)
set(B_PROJECT_CPP_MULTI_ARGS "${B_PROJECT_PYTHON_MULTI_ARGS};${B_SDK_HANDLER_PYSIDE_MULTI_ARGS}" PARENT_SCOPE)
cmake_parse_arguments(MY "" "" "${B_SDK_HANDLER_PYSIDE_MULTI_ARGS}" ${PROJECT_UNPARSED_ARGUMENTS})

# FIND TOOLS
###########
unset(PYSIDE_RCC_EXECUTABLE CACHE)
unset(PYSIDE_UIC_EXECUTABLE CACHE)

python_lib_path(PYSIDE_BINARY_DIR ${SDK_NAME} ${SDK_VERSION} TYPE BINARY)

find_program(PYSIDE_UIC_EXECUTABLE
				NAMES pyside-uic
				PATHS ${PYSIDE_BINARY_DIR}
				NO_DEFAULT_PATH
				)
	
if(NOT PYSIDE_UIC_EXECUTABLE)
	message(FATAL_ERROR "Didn't find pyside-uic executable in ${PYSIDE_BINARY_DIR}")
endif()

find_program(PYSIDE_RCC_EXECUTABLE
				NAMES pyside-rcc
				PATHS ${PYSIDE_BINARY_DIR}
				NO_DEFAULT_PATH
				)
	
if(NOT PYSIDE_UIC_EXECUTABLE)
	message(FATAL_ERROR "Didn't find pyside-rcc executable in ${PYSIDE_BINARY_DIR}")
endif()


# HANDLE RESOURCES
###################
file(GLOB_RECURSE RESOURCE_FILES "${CMAKE_CURRENT_SOURCE_DIR}/${PROJECT_ROOT_PACKAGE}/*.qrc")
if(RESOURCE_FILES)
	prominent_info("Setting up pyside resource compilation ...")
	foreach(PYSIDE_QRC_FILE IN LISTS RESOURCE_FILES)
		_pyside_convert_filename(${PYSIDE_QRC_FILE} rc PYSIDE_OUTPUT_FILE)
		list(APPEND PYSIDE_SRC_FILES ${PYSIDE_OUTPUT_FILE})
		add_custom_command(	OUTPUT ${PYSIDE_OUTPUT_FILE}
							COMMAND ${PYSIDE_RCC_EXECUTABLE}
								-o ${PYSIDE_OUTPUT_FILE} 
								${PYSIDE_QRC_FILE}
							DEPENDS
								${PYSIDE_QRC_FILE}
							)
	endforeach()
endif()

if(MY_PYSIDE_UI_FILES)
	prominent_info("Setting up pyside UI compilation ...")
	foreach(PYSIDE_UI_FILE IN LISTS MY_PYSIDE_UI_FILES)
		set(PYSIDE_UI_FILE ${CMAKE_CURRENT_SOURCE_DIR}/${PYSIDE_UI_FILE})
		_pyside_convert_filename(${PYSIDE_UI_FILE} ui PYSIDE_OUTPUT_FILE)
		list(APPEND PYSIDE_SRC_FILES ${PYSIDE_OUTPUT_FILE})
		add_custom_command(	OUTPUT ${PYSIDE_OUTPUT_FILE}
							COMMAND ${PYSIDE_UIC_EXECUTABLE}
								--from-imports
								-o ${PYSIDE_OUTPUT_FILE}
								${PYSIDE_UI_FILE}
							DEPENDS
								${PYSIDE_UI_FILE}
							)
	endforeach()
endif()


if(PYSIDE_SRC_FILES)
	# Create a target on which the python project depends, which uses our 
	# generated source files and thus will cause the them to be rebuilt
	# whenever required and demanded
	set(PYSIDE_TARGET pyside_${PROJECT_ID})
	add_custom_target(	${PYSIDE_TARGET}
						SOURCES ${PYSIDE_SRC_FILES})
						
	add_dependencies(${PROJECT_ID} ${PYSIDE_TARGET})
endif()

	
