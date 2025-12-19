#include<bits/stdc++.h>
using namespace std;

using ll=long long;
using vl= vector<long long>;
using vs=vector<string>;
using vi=vector<int>;
using vll=vector<pair<ll,ll>> ;
ll MOD=1e9+7;
void solve(){
	int n;
	ll x;
	cin>>n>>x;
	vl a(n);
	for(int i=0;i<n;i++){
		cin>>a[i];
	}
	vl dp(x+1);
	for(ll i=0;i<=x;i++){
		dp[i]=0;
	}
	dp[0]=1;
sort(a.begin(), a.end());
	for(ll i=1;i<=x;i++){
		

for (int j = 0; j < n; j++) {
    if (a[j] > i) break;
    dp[i] = (dp[i] + dp[i - a[j]]) % MOD;
}
		 
		
	}
	cout<<dp[x]<<endl;	
	}
	



int main(){
	ios::sync_with_stdio(false);
	cin.tie(nullptr);

	int t;
	t=1;
	while(t--){
		solve();
	}
	}
