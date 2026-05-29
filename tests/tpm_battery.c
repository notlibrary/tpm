/*
	TPM Toothpaste Picking Manager source code 0BSD license
	
	This is basically for unbelievers and skeptics we ran unit test battery consist of as
	much tests as possible against TPM API using oldest and most reliable C unit test framework libcheck
	I believe in dead simplicity theory underlying circular query algorithm is so dead simple that 
	it's just impossible to fail making most of tests useless anyway We'll see what really happens here
*/

#include <check.h>
#include <string.h>
#include <time.h>
#include "../src/tpm.h"


START_TEST (welcome_msg)
{
	ck_abort_msg("Welcome to the TPM test battery");
}
END_TEST

START_TEST (null_pick_msg)
{
	toothpaste_pick_t* pick=NULL;
	char* out=tpm_get_toothpaste_picking_message(pick);
	ck_assert_ptr_null(out);
}
END_TEST

START_TEST (null_pick_JSON)
{
	toothpaste_pick_t* pick=NULL;
	char* out=tpm_get_toothpaste_picking_JSON(pick);
	ck_assert_ptr_null(out);
}
END_TEST

START_TEST (null_pick_CSV)
{
	toothpaste_pick_t* pick=NULL;
	char* out=tpm_get_toothpaste_picking_CSV(pick);
	ck_assert_ptr_null (out);
}
END_TEST

START_TEST (length_pick_CSV)
{
	static list_node_t* toothpastes_list;
	toothpaste_pick_t* pick;
	toothpaste_pick_options_t topts;
	topts.formula.visit_dentist_times_per_year=2;
	topts.formula.swap_toothbrush_times_per_year=2;
	topts.ptype=0;
	int len;
	
	toothpastes_list=tpm_load_list_from_file("not/existimg/path");
	pick=tpm_pick_toothpaste(toothpastes_list,topts);
	char* out=tpm_get_toothpaste_picking_CSV(pick);
	len=strlen(out);
	ck_assert_int_gt(len,0);
}
END_TEST

START_TEST (length_pick_JSON)
{
	static list_node_t* toothpastes_list;
	toothpaste_pick_t* pick;
	toothpaste_pick_options_t topts;
	topts.formula.visit_dentist_times_per_year=2;
	topts.formula.swap_toothbrush_times_per_year=2;;
	topts.ptype=0;
	int len;
	
	toothpastes_list=tpm_load_list_from_file("not/existimg/path");
	pick=tpm_pick_toothpaste(toothpastes_list,topts);
	char* out=tpm_get_toothpaste_picking_JSON(pick);
	len=strlen(out);
	ck_assert_int_gt(len,0);
}
END_TEST

START_TEST (length_pick_msg)
{
	static list_node_t* toothpastes_list;
	toothpaste_pick_t* pick;
	toothpaste_pick_options_t topts;
	topts.formula.visit_dentist_times_per_year=2;
	topts.formula.swap_toothbrush_times_per_year=2;
	topts.ptype=0;
	int len;
	
	toothpastes_list=tpm_load_list_from_file("not/existimg/path");
	pick=tpm_pick_toothpaste(toothpastes_list,topts);
	char* out=tpm_get_toothpaste_picking_message(pick);
	len=strlen(out);
	ck_assert_int_gt(len,0);
}
END_TEST

START_TEST (prng_100_tries)
{
	int i = 0;
	unsigned long j=0;
	seed_xrp32(time(NULL));
	
	for (i=0;i<100;i++)
	{
		j = prng64_xrp32();
		ck_assert_uint_gt(j,0);
	}
	
}   
END_TEST

START_TEST (bad_toothpastes)
{
	static list_node_t* toothpastes_list;
	toothpaste_pick_t* pick;
	toothpaste_pick_options_t topts;
	topts.formula.visit_dentist_times_per_year=2;
	topts.formula.swap_toothbrush_times_per_year=2;
	topts.ptype=0;
	
	
	toothpastes_list=tpm_load_list_from_file("tests/bad_toothpastes.csv");
	pick=tpm_pick_toothpaste(toothpastes_list,topts);
	
	ck_assert_uint_eq(pick->total_toothpastes,3);
}
END_TEST




Suite* tpm_suite(void)
{
     Suite *s;
     TCase *tc_null_msg;
	 TCase *tc_prng;
	 TCase* tc_wrong_file;
 
     s = suite_create("TPM Battery");
 
     tc_null_msg = tcase_create("Null Pick output");
	 tc_prng = tcase_create("PRNG");
	 tc_wrong_file = tcase_create("Bad toothpastes");
	 
     tcase_add_test(tc_null_msg, welcome_msg);
     tcase_add_test(tc_null_msg, null_pick_msg);
	 tcase_add_test(tc_null_msg, null_pick_JSON);
	 tcase_add_test(tc_null_msg, null_pick_CSV);
     tcase_add_test(tc_null_msg, length_pick_msg);
	 tcase_add_test(tc_null_msg, length_pick_JSON);
	 tcase_add_test(tc_null_msg, length_pick_CSV);
	 
	 tcase_add_test(tc_prng, prng_100_tries);
	 
	 tcase_add_test(tc_wrong_file, bad_toothpastes);
	 
     suite_add_tcase(s, tc_null_msg);
	 suite_add_tcase(s, tc_prng);
     suite_add_tcase(s, tc_wrong_file);
     return s;
 }

int 
main(void)
{
     int number_failed;
     Suite *s;
     SRunner *sr;
 
     s = tpm_suite();
     sr = srunner_create(s);
 
     srunner_run_all(sr, CK_NORMAL);
     number_failed = srunner_ntests_failed(sr);
     srunner_free(sr);
     return (number_failed<= 1) ? EXIT_SUCCESS : EXIT_FAILURE;
	 
	 
 }