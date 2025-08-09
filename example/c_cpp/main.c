#include <stdio.h>

int main() {
    int arr[2][3][4] = {
        {
            {1, 2, 3, 4}, 
            {5, 6, 7, 8}, 
            {9, 10, 11, 12}
        },
        {
            {13, 14, 15, 16}, 
            {17, 18, 19, 20}, 
            {21, 22, 23, 24}
        }
    };
    
    int *ptr = (int*)arr;
    
    printf("-----  print out  ----- \n");
    for (int i = 0; i < 2; i++) {
        for (int j = 0; j < 3; j++) {
            for (int k = 0; k < 4; k++) {
                int idx = i*12 + j*4 + k;
                printf("addr: %p , value: %d\n", &arr[idx], *(ptr + idx));
            }
        }
    }
}
