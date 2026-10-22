#include <TMB.hpp>

// Modelo descritivo da população selecionada: efeitos normais nessa população,
// resposta BB condicionada a Y < N por linha e dado o efeito aleatório.
// upper_truncated=0 reproduz a BB ordinária para conferência independente.
template<class Type>
Type objective_function<Type>::operator() () {
  DATA_MATRIX(X);
  DATA_MATRIX(Z);
  DATA_VECTOR(y);
  DATA_VECTOR(N);
  DATA_IVECTOR(ies);
  DATA_IVECTOR(curso);
  DATA_INTEGER(n_ies);
  DATA_INTEGER(upper_truncated);
  PARAMETER_VECTOR(beta);
  PARAMETER_VECTOR(betadisp);
  PARAMETER_VECTOR(theta);
  PARAMETER_VECTOR(b);
  Type nll = 0;
  for (int j=0; j<b.size(); ++j)
    nll -= dnorm(b(j), Type(0), exp(theta(j<n_ies ? 0 : 1)), true);
  vector<Type> eta = X*beta;
  vector<Type> logphi = Z*betadisp;
  vector<Type> logprob(y.size());
  for (int i=0; i<y.size(); ++i) {
    if (upper_truncated && N(i)==Type(1)) {
      // Sob suporte {0}, log-probabilidade e gradientes são exatamente zero.
      logprob(i)=Type(0);
      continue;
    }
    Type mu = invlogit(eta(i)+b(ies(i))+b(n_ies+curso(i)));
    Type phi = exp(logphi(i));
    Type alpha = mu*phi, beta_shape = (Type(1)-mu)*phi;
    Type lp = lgamma(N(i)+Type(1))-lgamma(y(i)+Type(1))
      -lgamma(N(i)-y(i)+Type(1))
      +lbeta(y(i)+alpha,N(i)-y(i)+beta_shape)-lbeta(alpha,beta_shape);
    if (upper_truncated) {
      Type lp_upper = lbeta(N(i)+alpha,beta_shape)-lbeta(alpha,beta_shape);
      lp -= logspace_sub(Type(0),lp_upper);
    }
    logprob(i)=lp;
    nll -= lp;
  }
  REPORT(logprob);
  return nll;
}
