#include "ut.hpp"
#include ".hpp"
#include "tests.hpp"

void template_tests() {
	using namespace boost::ut;
	suite temptests = [] {
		"template"_test = [] {
			expect(1 == 1_i);
		};
	};
	return;
}