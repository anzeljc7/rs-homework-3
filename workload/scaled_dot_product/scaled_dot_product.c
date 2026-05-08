#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <riscv_vector.h>
#include <gem5/m5ops.h>

#define SEQ_LEN 256
#define D_K     64
#define SCALE   0.125f   /* 1/sqrt(64) */

/* ── Skalarna implementacija ─────────────────────────────────────────────── */

/* Skalarni produkt dveh vektorjev dolžine dim */
float dot_product(float *q, float *k, int dim)
{
    float result = 0.0f;
    for (int i = 0; i < dim; i++)
        result += q[i] * k[i];
    return result;
}

/* Softmax čez en vrstico dolžine len */
void softmax_row(float *scores, float *output, int len)
{
    /* Korak 1: najdi maksimum (numerična stabilnost) */
    float max_val = scores[0];
    for (int i = 1; i < len; i++)
        if (scores[i] > max_val)
            max_val = scores[i];

    /* Korak 2: exp in vsota */
    float sum = 0.0f;
    for (int i = 0; i < len; i++) {
        output[i] = expf((scores[i] - max_val) * SCALE);
        sum += output[i];
    }

    /* Korak 3: normalizacija */
    for (int i = 0; i < len; i++)
        output[i] /= sum;
}

/* ── Vektorska implementacija (RVV 1.0) ──────────────────────────────────── */

/*
 * Skalarni produkt z RVV strip-mining:
 * vsaka iteracija zmnoži pas vq*vk in ga takoj reducira v vsoto,
 * ki se prišteje k tekočemu rezultatu (skalarna akumulacija med pasovi).
 * Tako se izognemo problemu z "tail agnostic" politiko.
 */
float dot_product_rvv(float *q, float *k, int dim)
{
    float result = 0.0f;
    size_t i = 0;
    while (i < (size_t)dim) {
        size_t vl = __riscv_vsetvl_e32m1((size_t)dim - i);

        /* Naloži pas iz q[] in k[] */
        vfloat32m1_t vq = __riscv_vle32_v_f32m1(&q[i], vl);
        vfloat32m1_t vk = __riscv_vle32_v_f32m1(&k[i], vl);

        /* Elemntno množenje: vprod[j] = vq[j] * vk[j] */
        vfloat32m1_t vprod = __riscv_vfmul_vv_f32m1(vq, vk, vl);

        /* Redukcija pasu na skalar — začetna vrednost je tekoči result */
        vfloat32m1_t vinit = __riscv_vfmv_v_f_f32m1(result, 1);
        vfloat32m1_t vsum  = __riscv_vfredusum_vs_f32m1_f32m1(vprod, vinit, vl);
        result = __riscv_vfmv_f_s_f32m1_f32(vsum);

        i += vl;
    }
    return result;
}

/*
 * Softmax z delno RVV vektorizacijo:
 *   - iskanje maksimuma: vektorsko (vfredmax po pasovih)
 *   - izračun exp():     skalarno (expf() nima RVV različice)
 *   - normalizacija:     vektorsko (vfmul z 1/sum)
 */
void softmax_row_rvv(float *scores, float *output, int len)
{
    /* Korak 1: vektorsko iskanje maksimuma po pasovih */
    float max_val = scores[0];
    size_t i = 0;
    while (i < (size_t)len) {
        size_t vl = __riscv_vsetvl_e32m1((size_t)len - i);
        vfloat32m1_t vs    = __riscv_vle32_v_f32m1(&scores[i], vl);
        /* Začetna vrednost redukcije je tekoči maksimum */
        vfloat32m1_t vinit = __riscv_vfmv_v_f_f32m1(max_val, 1);
        vfloat32m1_t vmax  = __riscv_vfredmax_vs_f32m1_f32m1(vs, vinit, vl);
        max_val = __riscv_vfmv_f_s_f32m1_f32(vmax);
        i += vl;
    }

    /* Korak 2: exp() — ostane skalarna zanka (ni RVV exp intrinzike) */
    float sum = 0.0f;
    for (int j = 0; j < len; j++) {
        output[j] = expf((scores[j] - max_val) * SCALE);
        sum += output[j];
    }

    /* Korak 3: vektorska normalizacija z množenjem z 1/sum */
    float inv_sum = 1.0f / sum;
    i = 0;
    while (i < (size_t)len) {
        size_t vl = __riscv_vsetvl_e32m1((size_t)len - i);
        vfloat32m1_t vout = __riscv_vle32_v_f32m1(&output[i], vl);
        vout = __riscv_vfmul_vf_f32m1(vout, inv_sum, vl);
        __riscv_vse32_v_f32m1(&output[i], vout, vl);
        i += vl;
    }
}

/* ── Glavni program ──────────────────────────────────────────────────────── */

int main()
{
    float Q[SEQ_LEN][D_K];
    float K[SEQ_LEN][D_K];

    /* Ločena polja za rezultate — da merjeni regiji ne vplivata drug na drugega */
    float scores_scalar[SEQ_LEN], attn_scalar[SEQ_LEN];
    float scores_vector[SEQ_LEN], attn_vector[SEQ_LEN];

    for (int i = 0; i < SEQ_LEN; i++)
        for (int j = 0; j < D_K; j++) {
            Q[i][j] = (float)(i + j) * 0.01f;
            K[i][j] = (float)(i - j) * 0.01f;
        }

    /* ── Skalarna meritev ────────────────────────────────────────────────── */
    #ifdef GEM5
        m5_reset_stats(0, 0);
    #endif

    for (int j = 0; j < SEQ_LEN; j++)
        scores_scalar[j] = dot_product(Q[0], K[j], D_K);
    softmax_row(scores_scalar, attn_scalar, SEQ_LEN);

    #ifdef GEM5
        m5_dump_stats(0, 0);
    #endif

    /* ── Vektorska meritev (RVV) ─────────────────────────────────────────── */
    #ifdef GEM5
        m5_reset_stats(0, 0);
    #endif

    for (int j = 0; j < SEQ_LEN; j++)
        scores_vector[j] = dot_product_rvv(Q[0], K[j], D_K);
    softmax_row_rvv(scores_vector, attn_vector, SEQ_LEN);

    #ifdef GEM5
        m5_dump_stats(0, 0);
    #endif

    /* ── Preveritev pravilnosti (primerjava scalar vs. vector) ───────────── */
    float max_err = 0.0f;
    for (int i = 0; i < SEQ_LEN; i++) {
        float diff = fabsf(attn_scalar[i] - attn_vector[i]);
        if (diff > max_err) max_err = diff;
    }
    printf("Preveritev: max |scalar - vector| = %.2e  %s\n",
           max_err, max_err < 1e-5f ? "[OK]" : "[NAPAKA]");

    for (int i = 0; i < 4; i++)
        printf("attn[%d] = %.6f\n", i, attn_vector[i]);

    return max_err < 1e-5f ? 0 : 1;
}
