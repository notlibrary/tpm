/*
This is basically for unbelievers and skeptics we ran unit test battery consist of as
much tests as possible against TPM API using oldest and most reliable C unit test framework libcheck
I believe in dead simplicity theory underlying circular query algorithm is so dead simple that 
it's just impossible to fail making most of tests useless anyway We'll see what really happens here
*/

#include <check.h>

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
	ck_assert_str_eq(out,NULL);
}
END_TEST

START_TEST (null_pick_JSON)
{
	toothpaste_pick_t* pick=NULL;
	char* out=tpm_get_toothpaste_picking_JSON(pick);
	ck_assert_str_eq(out,NULL);
}
END_TEST

START_TEST (null_pick_CSV)
{
	toothpaste_pick_t* pick=NULL;
	char* out=tpm_get_toothpaste_picking_CSV(pick);
	ck_assert_str_eq(out,NULL);
}
END_TEST

Suite* tpm_suite(void)
{
     Suite *s;
     TCase *tc_null_msg;

 
     s = suite_create("TPM Battery");
 
     tc_null_msg = tcase_create("Null Pick output");
	 
     tcase_add_test(tc_null_msg, welcome_msg);
     tcase_add_test(tc_null_msg, null_pick_msg);
	 tcase_add_test(tc_null_msg, null_pick_JSON);
	 tcase_add_test(tc_null_msg, null_pick_CSV);
	 
     suite_add_tcase(s, tc_null_msg);
     
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