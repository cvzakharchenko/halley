include(PrecompiledHeader)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if (${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++14 -stdlib=libc++") # Apparently Clang on Mac needs this...
endif()

if (MSVC)
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /MP /fp:fast")
	set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /GL /sdl /Oi /Ot /Oy")
	set(CMAKE_EXE_LINKER_FLAGS_RELEASE "${CMAKE_EXE_LINKER_FLAGS_RELEASE} /LTCG")
	set(CMAKE_STATIC_LINKER_FLAGS_RELEASE "${CMAKE_STATIC_LINKER_FLAGS_RELEASE} /LTCG")
	set(CMAKE_SHARED_LINKER_FLAGS_RELEASE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE} /LTCG")
	
	set(SDL2_LIBRARIES "")
	set(YAMLCPP_LIBRARY "")
	set(Boost_FILESYSTEM_LIBRARY "")
	set(Boost_SYSTEM_LIBRARY "")
	set(Boost_THREAD_LIBRARY "")
else()
	set(EXTRA_LIBS pthread)
	set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -D_DEBUG")

	find_package(YamlCpp REQUIRED)
	find_Package(SDL2 REQUIRED)
	find_package(OpenGL REQUIRED)
	find_package(Boost COMPONENTS system filesystem thread REQUIRED)
	
	set(FREETYPE_LIB_DEBUG ${FREETYPE_LIB})
	set(YAMLCPP_LIBRARY_DEBUG ${YAMLCPP_LIBRARY})
endif()

# From http://stackoverflow.com/questions/31422680/how-to-set-visual-studio-filters-for-nested-sub-directory-using-cmake
function(assign_source_group)
	foreach(_source IN ITEMS ${ARGN})
		if (IS_ABSOLUTE "${_source}")
			file(RELATIVE_PATH _source_rel "${CMAKE_CURRENT_SOURCE_DIR}" "${_source}")
		else()
			set(_source_rel "${_source}")
		endif()
		get_filename_component(_source_path "${_source_rel}" PATH)
		string(REPLACE "/" "\\" _source_path_msvc "${_source_path}")
		source_group("${_source_path_msvc}" FILES "${_source}")
	endforeach()
endfunction(assign_source_group)

set(CMAKE_DEBUG_POSTFIX "_d")

set(HALLEY_PROJECT_LIBS
	optimized halley-core
	optimized halley-utils
	optimized halley-opengl
	optimized halley-entity
	debug halley-core_d
	debug halley-utils_d
	debug halley-opengl_d
	debug halley-entity_d
	${SDL2_LIBRARIES}
	${YAMLCPP_LIBRARY}
	${Boost_FILESYSTEM_LIBRARY}
	${Boost_SYSTEM_LIBRARY}
	${Boost_THREAD_LIBRARY}
	${EXTRA_LIBS}
	)

set(HALLEY_PROJECT_INCLUDE_DIRS
	${HALLEY_PATH}/include
	${HALLEY_PATH}/halley/core/include
	${HALLEY_PATH}/halley/utils/include
	${HALLEY_PATH}/halley/entity/include
	${YAMLCPP_INCLUDE_DIR}
	)
	
set(HALLEY_PROJECT_LIB_DIRS
	${HALLEY_PATH}/lib
	)

function(halleyProject name sources headers genDefinitions targetDir)
	add_custom_target(${name}_codegen ALL ${HALLEY_PATH}/bin/halley-cmd codegen gen_src gen WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR} DEPENDS ${genDefinitions})

	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${targetDir})
	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELEASE ${targetDir})
	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${targetDir})
	set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_RELWITHDEBINFO ${targetDir})

	file (GLOB_RECURSE ${name}_sources_gen "gen/*.cpp")
	file (GLOB_RECURSE ${name}_sources_systems "src/systems/*.cpp")
	file (GLOB_RECURSE ${name}_headers_gen "gen/*.h")
	
	set(proj_sources ${sources} ${${name}_sources_gen} ${${name}_sources_systems})
	set(proj_headers ${headers} ${${name}_headers_gen} ${genDefinitions})

	assign_source_group(${proj_sources})
	assign_source_group(${proj_headers})

	include_directories("." "gen/cpp" ${HALLEY_PROJECT_INCLUDE_DIRS})
	link_directories(${HALLEY_PROJECT_LIB_DIRS})

	if(MSVC_)
		add_library(${name} SHARED ${proj_sources} ${proj_headers})
		add_definitions(-DHALLEY_SHARED_LIBRARY)
	else()
		add_executable(${name} ${proj_sources} ${proj_headers})
		add_definitions(-DHALLEY_EXECUTABLE)
	endif()

	target_link_libraries(${name} ${HALLEY_PROJECT_LIBS})
	set_target_properties(${name} PROPERTIES DEBUG_POSTFIX ${CMAKE_DEBUG_POSTFIX})
	add_dependencies(${name} ${name}_codegen)
	
	if(MSVC)
		add_precompiled_header(${name} prec.h FORCEINCLUDE SOURCE_CXX prec.cpp)
	endif()
endfunction(halleyProject)