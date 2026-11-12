#line 3 "vcast_preprocess.16792.1010.c"                                                                                                                              
# 1 "vcast_preprocess.16792.1008.c" 1

typedef int VECTORCAST_MARKER__UNIT_PREFIX_START;

typedef int VECTORCAST_MARKER__UNIT_PREFIX_END;
# 1 "C:/VCAST/Environments/TEST_VEC/TEST_VEC.c" 1
# 1 "C:/VCAST/Environments/TEST_VEC/TEST_VEC.h" 1


int divide(int a, int b);
int check_status(int temp, int voltage, int error_flag);
# 2 "C:/VCAST/Environments/TEST_VEC/TEST_VEC.c" 2
int divide(int a, int b) { /*vcast_internal_start*/
extern int P_9_1_1;
extern int P_9_1_2;
extern int R_9_1;
extern unsigned char SBF_9_1;
if(SBF_9_1) {
  vCAST_USER_CODE_TIMER_STOP();
#define BEGINNING_OF_STUB_USER_CODE_9_2208222536
#include "vcast_configure_stub.c"
#undef BEGINNING_OF_STUB_USER_CODE_9_2208222536
  if ( vcast_is_in_driver ) {
    P_9_1_1 = a;
    P_9_1_2 = b;
    vCAST_COMMON_STUB_PROC_9( 9, 1, 3, 0 );
  } /* vcast_is_in_driver */
#define END_OF_STUB_USER_CODE_9_2208222536
#include "vcast_configure_stub.c"
#undef END_OF_STUB_USER_CODE_9_2208222536
  vCAST_USER_CODE_TIMER_START();
  return R_9_1;
}
{ /*vcast_internal_end*/

    if (b == 0) return -1;
    return a / b;
} /*vcast_internal_start*/}/*vcast_internal_end*/

int check_status(int temp, int voltage, int error_flag) { /*vcast_internal_start*/
extern int P_9_2_1;
extern int P_9_2_2;
extern int P_9_2_3;
extern int R_9_2;
extern unsigned char SBF_9_2;
if(SBF_9_2) {
  vCAST_USER_CODE_TIMER_STOP();
#define BEGINNING_OF_STUB_USER_CODE_9_250649779
#include "vcast_configure_stub.c"
#undef BEGINNING_OF_STUB_USER_CODE_9_250649779
  if ( vcast_is_in_driver ) {
    P_9_2_1 = temp;
    P_9_2_2 = voltage;
    P_9_2_3 = error_flag;
    vCAST_COMMON_STUB_PROC_9( 9, 2, 4, 0 );
  } /* vcast_is_in_driver */
#define END_OF_STUB_USER_CODE_9_250649779
#include "vcast_configure_stub.c"
#undef END_OF_STUB_USER_CODE_9_250649779
  vCAST_USER_CODE_TIMER_START();
  return R_9_2;
}
{ /*vcast_internal_end*/

    if ((temp > 80 || voltage < 10) && error_flag == 0) return 1;
    else if (error_flag != 0) return 2;
    return 0;
} /*vcast_internal_start*/}/*vcast_internal_end*/

# 6 "vcast_preprocess.16792.1008.c" 2

 /*vcast_internal_start*/
int P_9_1_1;
int P_9_1_2;
int R_9_1;
unsigned char SBF_9_1 = 0;

/*vcast_internal_end*/
 /*vcast_internal_start*/
int P_9_2_1;
int P_9_2_2;
int P_9_2_3;
int R_9_2;
unsigned char SBF_9_2 = 0;

/*vcast_internal_end*/
typedef int VECTORCAST_MARKER__UNIT_APPENDIX_START;

typedef int VECTORCAST_MARKER__UNIT_APPENDIX_END;
# 4 "vcast_preprocess.16792.1010.c" 2

                                               
