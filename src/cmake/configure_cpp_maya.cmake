
function(configure_cpp_maya)
	if(B_CPP_MAYA_CONFIGURED)
		error("configure_cpp called multiple times")
	endif()
	
	#NOTE: For now, we preset it to 10.6 - this is somewhat deprecated but
	#required by maya. Its only required for maya plug-ins, and this code 
	# will only be called if they are not excluded.
	if(APPLE)
		set(CMAKE_FRAMEWORK_PATH "/Developer/SDKs/MacOSX10.6.sdk" CACHE STRING
			"Directory containing all the osx 10.6 headers")
		
		if(NOT EXISTS ${CMAKE_FRAMEWORK_PATH})
			message(SEND_ERROR "SYSROOT include directory not found at ${CMAKE_FRAMEWORK_PATH} - please configure it in your cmake cache and try again")
		endif()
	endif()

	# finally, mark us configured
	set(B_CPP_MAYA_CONFIGURED YES CACHE INTERNAL "marks cpp projects (generally) configured" FORCE)
endfunction()
