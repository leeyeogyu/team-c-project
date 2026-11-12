#include "TEST_VEC.h"
int divide(int a, int b) {
    if (b == 0) return -1;
    return a / b;
}
int check_status(int temp, int voltage, int error_flag) {
    if ((temp > 80 || voltage < 10) && error_flag == 0) return 1;
    else if (error_flag != 0) return 2;
    return 0;
}
