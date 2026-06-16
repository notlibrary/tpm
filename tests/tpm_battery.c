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
	char* out;
	tpm_get_toothpaste_picking_message(pick,&out);
	ck_assert_ptr_null(out);
}
END_TEST

START_TEST (null_pick_JSON)
{
	toothpaste_pick_t* pick=NULL;
	char* out;
	tpm_get_toothpaste_picking_JSON(pick,&out);
	ck_assert_ptr_null(out);
}
END_TEST

START_TEST (null_pick_CSV)
{
	toothpaste_pick_t* pick=NULL;
	char* out;
	tpm_get_toothpaste_picking_CSV(pick,&out);
	ck_assert_ptr_null (out);
}
END_TEST

START_TEST (length_pick_CSV)
{
	list_node_t* toothpastes_list = NULL;
	toothpaste_pick_t pick = {0};           
	toothpaste_pick_options_t topts = {0};   

	char template_buffer[] = "guwntdapobiTfWPlUsmI"; 
	tpm_init_context(&topts);
	
	topts.formula.visit_dentist_times_per_year = 2;
	topts.formula.swap_toothbrush_times_per_year = 2;
	topts.ptype = 0;
	topts.tpm_template = template_buffer;
	topts.username = "TestUser";
	topts.meme_payload = "moot";

	int len;
	
	const char* test_filename = "test_fixtures_csv.txt";
	FILE* f = fopen(test_filename, "w");
	ck_assert_ptr_nonnull(f); 
	fprintf(f, "1, Colgate, 75, 5, Blue, Oral-B, 19, 2\n");
	fclose(f);
	
	tpm_load_list_from_file(test_filename,&topts,&toothpastes_list);
	ck_assert_ptr_nonnull(toothpastes_list);

	tpm_pick_toothpaste(toothpastes_list, &topts, &pick);
	
	char* out;
	tpm_get_toothpaste_picking_CSV(&pick,&out);
	ck_assert_ptr_nonnull(out);
	
	len = strlen(out);
	ck_assert_int_gt(len, 0);
	
	remove(test_filename);
}
END_TEST

START_TEST (length_pick_JSON)
{
	list_node_t* toothpastes_list = NULL;
	toothpaste_pick_t pick = {0};           
	toothpaste_pick_options_t topts = {0};   
	
	char template_buffer[] = "guwntdapobiTfWPlUsmI";
	tpm_init_context(&topts);
	topts.formula.visit_dentist_times_per_year = 2;
	topts.formula.swap_toothbrush_times_per_year = 2;
	topts.ptype = 0;
	topts.tpm_template = template_buffer;
	topts.username = "TestUser";
	topts.meme_payload = "moot";
	
	int len;
	
	const char* test_filename = "test_fixtures_json.txt";
	FILE* f = fopen(test_filename, "w");
	ck_assert_ptr_nonnull(f); 
	fprintf(f, "1, Colgate, 75, 5, Blue, Oral-B, 19, 2\n");
	fclose(f);
	
	tpm_load_list_from_file(test_filename,&topts,&toothpastes_list);
	ck_assert_ptr_nonnull(toothpastes_list);

	tpm_pick_toothpaste(toothpastes_list, &topts, &pick);
	
	char* out;
    tpm_get_toothpaste_picking_JSON(&pick,&out);
	ck_assert_ptr_nonnull(out);
	
	len = strlen(out);
	ck_assert_int_gt(len, 0);
	
	remove(test_filename);
}
END_TEST

START_TEST (length_pick_msg)
{
	list_node_t* toothpastes_list = NULL;
	toothpaste_pick_t pick = {0};            
	toothpaste_pick_options_t topts = {0};   
	
	
	char template_buffer[] = "guwntdapobiTfWPlUsmI";
	tpm_init_context(&topts);
	topts.formula.visit_dentist_times_per_year = 2;
	topts.formula.swap_toothbrush_times_per_year = 2;
	topts.ptype = 0;
	topts.tpm_template = template_buffer; 
	topts.meme_payload = "moot";
	topts.username = "TestUser";
	
	int len;
	
	const char* test_filename = "test_fixtures_toothpastes.txt";
	FILE* f = fopen(test_filename, "w");
	ck_assert_ptr_nonnull(f); 
	fprintf(f, "1, Colgate, 75, 5, Blue, Oral-B, 19, 2\n");
	fclose(f);
	
	tpm_load_list_from_file(test_filename,&topts,&toothpastes_list );
	ck_assert_ptr_nonnull(toothpastes_list);

	tpm_pick_toothpaste(toothpastes_list, &topts, &pick);
	
	char* out;
	tpm_get_toothpaste_picking_message(&pick,&out);
	ck_assert_ptr_nonnull(out);
	
	len = strlen(out);
	ck_assert_int_gt(len, 0);
	
	remove(test_filename);
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
	list_node_t* toothpastes_list = NULL;
	toothpaste_pick_options_t topts;
	tpm_init_context(&topts);
	tpm_load_list_from_file("not/exist",&topts,&toothpastes_list);
	
	unsigned int i=0;
	list_node_t* current = toothpastes_list;
	
    while (current != NULL) 
	{
        i++;
        current = current->next;
	}
	
	ck_assert_uint_eq(i,3);
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