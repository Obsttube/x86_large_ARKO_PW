/*==========================================================================*
 * author:				Piotr Obst											*
 * date:				02.01.2021											*
 * description:			"Big" INTEL x86 project - finding 8th-type marker	*
 *							in a BMP file with arbitrary dimensions.		*
 * usage:				find_markers [options]								*
 * options:																	*
 *   -f <filename>		Find markers in the <filename> file.				*
 *   -t					Find markers in all files in the 'tests' directory	*
 *							and compare them with the correct output.		*
 *							Eg. test1.o contains correct output for the		*
 *							test1.bmp file.									*
 *==========================================================================*/

#include <stdio.h>
#include <stdlib.h>
#include <getopt.h>		// for command-line parameters
#include <stdbool.h>	// for bool variables
#include <dirent.h>		// for working with directories
#include <sys/stat.h>	// for checking if files exist and mkdir()
#include <string.h>		// for strlen(), strcpy()

extern "C" int find_markers(unsigned char *bitmap, unsigned int *x_pos, unsigned int *y_pos);

bool test_a_file(char *bmp_filename, char *out_filename);
int find_markers_in_file(char *filename, unsigned int *x_pos, unsigned int *y_pos);

int main(int argc, char *argv[])
{
	if (argc == 1)
	{
		printf("No parameters supplied.\n");
		printf("Type '%s -h' for help.\n", argv[0]);
		return 1;
	}
	char option;
	char *filename = NULL;
	bool test = false;
	int num_of_args = 0;
	while (( option = getopt(argc, argv, "hf:t")) != -1){
		num_of_args++;
		switch (option) {
			case 'h':
				printf("Usage: %s [options]\n", argv[0]);
				printf("Options:\n");
				printf("  -f <filename>\tFind markers in the <filename> file.\n");
				printf("  -t\t\tFind markers in all files in the 'tests' directory and compare\n");
				printf("\t\tthem with the correct output. Eg. test1.o contains correct output\n");
				printf("\t\tfor the test1.bmp file.\n");
				return 0;
			case 'f':
				filename = optarg;
				num_of_args++;
				break;
			case 't':
				test = true;
				break;
			case '?':
				printf("Type '%s -h' for help.\n", argv[0]);
				return 1;
		}
	}
	if (num_of_args < argc - 1)
	{
		printf("Unsupported parameters supplied.\n");
		printf("Type '%s -h' for help.\n", argv[0]);
		return 1;
	}
	
	if (filename != NULL)
	{
		unsigned int *x_pos = new unsigned int [50];
		unsigned int *y_pos = new unsigned int [50];
		int number_of_markers = find_markers_in_file(filename, x_pos, y_pos);
		if (number_of_markers == -2)
		{
			printf("Can't open '%s' file. Does it exist?\n", filename);
		}
		else if (number_of_markers == -1)
		{
			printf("'%s' is not a bmp file!\n", filename);
		}
		else
			for (int i = 0; i < number_of_markers; i++)
				printf("%i, %i\n", x_pos[i], y_pos[i]);
		free(x_pos);
		free(y_pos);
	}
	
	if (test)
	{
		printf("Testing with files in the 'tests' directory...\n");
		struct dirent *dir;
		DIR *d = opendir("./tests");
		if (d)
		{
			int files_found = 0;
			int num_passed = 0;
			int num_failed = 0;
			int num_skipped = 0;
			while ((dir = readdir(d)) != NULL)
			{
				char *bmp_file_name = dir -> d_name;
				int filename_len = strlen(bmp_file_name);
				if (filename_len < 5 || bmp_file_name[filename_len-4] != '.'
					|| (bmp_file_name[filename_len-3] != 'B' && bmp_file_name[filename_len-3] != 'b')
					|| (bmp_file_name[filename_len-2] != 'M' && bmp_file_name[filename_len-2] != 'm')
					|| (bmp_file_name[filename_len-1] != 'P' && bmp_file_name[filename_len-1] != 'p'))
					continue;
				files_found++;
				char *test_file_name = new char[filename_len+1];
				strcpy(test_file_name, bmp_file_name);
				test_file_name[filename_len-3] = 'o';
				test_file_name[filename_len-2] = '\0';
				char *test_file_path = new char[filename_len + 10];
				strcpy(test_file_path, "./tests/");
				strcat(test_file_path, test_file_name);
				struct stat buffer;
				if (stat(test_file_path, &buffer) == -1)
				{
					printf("Output file corresponding to '%s' has not been found, skipping!\n", bmp_file_name);
					num_skipped++;
					continue;
				}
				char *bmp_file_path = new char[filename_len + 10];
				strcpy(bmp_file_path, "./tests/");
				strcat(bmp_file_path, bmp_file_name);
				if (test_a_file(bmp_file_path, test_file_path))
					num_passed++;
				else
				{
					num_failed++;
					printf("'%s' FAILED the test!\n", bmp_file_name);
				}
				free(bmp_file_path);
				free(test_file_path);
				free(test_file_name);
			}
			if (files_found == 0)
				printf("No *.bmp files found in the 'tests' directory.\n");
			else
			{
				printf("Files that PASSED the test: %i\n", num_passed);
				printf("Files that FAILED the test: %i\n", num_failed);
				printf("Skipped files: %i\n", num_skipped);
			}
			closedir(d);
		}
		else
		{
			printf("'test' directory not found. Creating it...\n");
			mkdir("./tests", 0744);
			printf("Done. Now you can put test files in there.\n");
		}
	}
	
	return 0;
}

bool test_a_file(char *bmp_file_path, char *out_file_path)
{
	bool is_passed = true;
	
	unsigned int *x_pos = new unsigned int [50];
	unsigned int *y_pos = new unsigned int [50];
	
	int number_of_markers = find_markers_in_file(bmp_file_path, x_pos, y_pos);
	if (number_of_markers == -2)
	{
		printf("File '%s' deleted during execution. Exiting...", bmp_file_path);
		exit(1);
	}
	else if (number_of_markers == -1)
	{
		printf("'%s' is not a bmp file! (fail)\n", bmp_file_path);
		free(x_pos);
		free(y_pos);
		return false;
	}
	
	FILE * file;
    char * line = NULL;
    size_t len = 0;
    ssize_t line_len;

    file = fopen(out_file_path, "r");
    if (file == NULL)
	{
		printf("File '%s' deleted during execution. Exiting...", out_file_path);
		exit(1);
	}
	
	int line_num = 0;
    while ((line_len = getline(&line, &len, file)) != -1) {
		if (line_num > number_of_markers)
		{
			is_passed = false;
			break;
		}
		char* buf = (char *) malloc(line_len + 2);
		line_num++;
		bool found = false;
		
		for (int i = 0; i< number_of_markers; i++)
		{
			snprintf(buf, line_len + 2, "%d, %d", x_pos[i], y_pos[i]);
			line[strcspn(line, "\r\n")] = '\0';  // remove line endings (all \r, \n, \r\n, \n\r)
			if (strcmp(buf, line) == 0)
			{
				found = true;
				break;
			}
		}
		
		free(buf);
		if (found == false)
		{
			is_passed = false;
			break;
		}
    }
	
	if (line_num != number_of_markers)
		is_passed = false;

    fclose(file);
	free(x_pos);
	free(y_pos);
	return is_passed;
}

int find_markers_in_file(char *filename, unsigned int *x_pos, unsigned int *y_pos)
{
	unsigned char *bitmap;
	
	FILE *file;
	long length;
	
	file = fopen(filename, "rb");	// rb = read, binnary mode
	if (file == NULL)
		return -2;
	fseek(file, 0, SEEK_END);		// go to the end
	length = ftell(file);			// get number of bytes
	bitmap = (unsigned char *) malloc(length * sizeof(unsigned char));	// allocate memory
	fseek(file, 0, SEEK_SET);		// go to the beginning
	fread(bitmap, length, 1, file);
	fclose(file);
	
	int output = find_markers(bitmap, x_pos, y_pos);
	free(bitmap);
	return output;
}
