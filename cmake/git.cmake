find_program(GIT_EXECUTABLE NAMES git DOC "git version control")

# ==============================================================================
# sets RESULT_VARIABLEIABLE to a true value if git is available.
# If this is a false value, you may not call any of the provided utility functions
# as they will fail.
# You must call this function for portability
# ==============================================================================
function(git_available RESULT_VARIABLE)
	set(${RESULT_VARIABLE} TRUE PARENT_SCOPE)
	if (GIT_EXECUTABLE)
		set(${RESULT_VARIABLE} FALSE PARENT_SCOPE)
	endif()
endfunction()

# ==============================================================================
# get all tags from a repository returned as a list
#
# REPO_PATH		full path to a valid git repository
# ==============================================================================
function(git_list_tags REPO_PATH RESULT_VARIABLE)
	execute_process(
		COMMAND ${GIT_EXECUTABLE} tag -l 
		WORKING_DIRECTORY ${REPO_PATH} 
		OUTPUT_VARIABLE GIT_OUTPUT)
	string(REPLACE "\n" ";" GIT_TAGS ${GIT_OUTPUT})
	set(${RESULT_VARIABLE} ${GIT_TAGS} PARENT_SCOPE)
endfunction()

# ==============================================================================
# get all branches from a reposity returned as a list
#
# REPO_PATH		full path to a valid git repository
# ==============================================================================
function(git_list_branches REPO_PATH RESULT_VARIABLE)
	execute_process(
		COMMAND ${GIT_EXECUTABLE} branch -a
		WORKING_DIRECTORY ${REPO_PATH} 
		OUTPUT_VARIABLE GIT_OUTPUT)
	string(REGEX REPLACE "[ ]+" "" GIT_BRANCHES ${GIT_OUTPUT})
	string(REPLACE "\n" ";" GIT_BRANCHES ${GIT_BRANCHES})
	set(${RESULT_VARIABLE} ${GIT_BRANCHES} PARENT_SCOPE)
endfunction()

# ==============================================================================
# actual git command to switch to revision or branch
# NOTE: throws an error if the checkout fails
# REPO_PATH		full path to a valid git repository
# REVISION		a valid git checkout target (tag, commit or branch)
# ==============================================================================
function(git_checkout REPO_PATH REVISION)
	execute_process(  	COMMAND ${GIT_EXECUTABLE} checkout ${REVISION} 
						WORKING_DIRECTORY ${REPO_PATH}
						RESULT_VARIABLE EXIT_CODE
						ERROR_VARIABLE STDERR )
		
	if(NOT EXIT_CODE EQUAL 0)
		error("Failed to checkout revision ${REVISION} at ${REPO_PATH} with error: ${STDERR}")
	endif()
endfunction()

# ==============================================================================
# use git clean to get a repository to a clean state
# similar to what one would expect 'make clean' to do, but guarantees
# it will find everything that is not checked-in
#
# REPO_PATH		full path to a valid git repository
# ==============================================================================
function(git_clean REPO_PATH)
	message(STATUS "git cleaning ${REPO_PATH}")
	execute_process(
		COMMAND ${GIT_EXECUTABLE} clean -dfx
		WORKING_DIRECTORY ${REPO_PATH})
endfunction()
