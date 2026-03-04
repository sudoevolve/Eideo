cmake_minimum_required(VERSION 3.16)
project(Eideo VERSION 0.1 LANGUAGES CXX)
find_package(Qt6 REQUIRED COMPONENTS Quick Multimedia Network)
qt_standard_project_setup(REQUIRES 6.8)
qt_add_executable(Eideo
    main.cpp
    FFmpegRunner.h
    FFmpegRunner.cpp
    RealESRGANRunner.h
    RealESRGANRunner.cpp
    Task.h
    TaskManager.h
    TaskManager.cpp
)
file(GLOB_RECURSE QML_COMPONENTS RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "components/*.qml")
file(GLOB_RECURSE QML_PAGES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} CONFIGURE_DEPENDS "pages/*.qml")

qt_add_qml_module(Eideo
    URI EvolveUI
    VERSION 1.0
    QML_FILES
                Main.qml
                ${QML_PAGES}
                ${QML_COMPONENTS}
)
qt_add_resources(APP_RESOURCES
    src.qrc
)
target_sources(Eideo PRIVATE ${APP_RESOURCES})
target_link_libraries(Eideo PRIVATE Qt6::Quick Qt6::Multimedia Qt6::Network)
set_target_properties(Eideo PROPERTIES WIN32_EXECUTABLE TRUE)
