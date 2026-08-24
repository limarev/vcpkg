cmake_minimum_required(VERSION 3.20)
project(argparse_test LANGUAGES CXX)

find_package(argparse CONFIG REQUIRED)

add_executable(argparse-test main.cpp)
target_link_libraries(argparse-test PRIVATE argparse::argparse)
