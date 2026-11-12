#line 3 "vcast_preprocess.16792.1010.c"                                                                                                                              
# 1 "vcast_preprocess.16792.1008.c" 1

typedef int VECTORCAST_MARKER__UNIT_PREFIX_START;

typedef int VECTORCAST_MARKER__UNIT_PREFIX_END;
# 1 "C:/VCAST/Environments/TEST_VEC/TEST_VEC.c" 1
# 1 "C:/VCAST/Environments/TEST_VEC/TEST_VEC.h" 1


int divide(int a, int b);
int check_status(int temp, int voltage, int error_flag);
# 2 "C:/VCAST/Environments/TEST_VEC/TEST_VEC.c" 2
int divide(int a, int b) {
    if (b == 0) return -1;
    return a / b;
}
int check_status(int temp, int voltage, int error_flag) {
    if ((temp > 80 || voltage < 10) && error_flag == 0) return 1;
    else if (error_flag != 0) return 2;
    return 0;
}
# 6 "vcast_preprocess.16792.1008.c" 2

typedef int VECTORCAST_MARKER__UNIT_APPENDIX_START;

typedef int VECTORCAST_MARKER__UNIT_APPENDIX_END;
# 4 "vcast_preprocess.16792.1010.c" 2

                                               
