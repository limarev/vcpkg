#include <argparse/argparse.hpp>

int main()
{
    argparse::ArgumentParser parser("argparse-test");
    return parser.get_program_name() == "argparse-test" ? 0 : 1;
}
