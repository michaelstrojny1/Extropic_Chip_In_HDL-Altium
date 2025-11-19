**Summary**

This repository is work in progress. We attempt to build a simple version of Extropic's Stoichastic Processing Unit in Verilog and build a 16 bit version in Altium. Our architecture follows Extropic's Paper, "An efficient probabilistic hardware architecture for diffusion-like models" by Andraž Jelinčič et al (https://arxiv.org/pdf/2510.23972) [1].

**Very high level overview of our proposed implementation (Top --> Bottom modules)**

Top level processor (controls and schedules EBM sampling and training) --> 
quadratic energy model implemented on 70x70 grid of binary nodes with G12 [1] connectivity  --> 
Weight memory (i.e store and load the weights for the current time step)

**Brief Background**

The Extropic architecture samples complex probability distributions efficiency by breaking the distribution into a product of many simple distributions over binary variables that are easy to sample. These simple distributions are modelled by a quadratic energy over a 70x70 grid of binary nodes where a percentage of nodes are latent hidden states for computational purposes (i.e a latent state) and the rest are visible nodes. For each node, we create connections with nodes at (x+a,y+b), (x−b,y+a), (x−a,y−b), (x+b,y−a). The paper suggests using 3 sets of connections (a, b) = (0,1), (4,1), (9,10). They call this G12 connectivity; it captures short, medium and long range interactions respectively. They also define other connectivity patterns which you can read more about in Appendix C of the paper. If we label every even index node as black and every odd index node as white, each node's energy would only depend on nodes of opposite colour. This speeds up the sampling of the graph from O(L^2) to O(2), as we can update each colour of nodes in parallel at a time. Since we model a joint distribution, each 70x70 grid should model $P(x_n | x_{n-1})$; we condition the visible nodes on $x_{n-1}$ by connecting $x_{n}$ and $x_{n-1}$ with 1-1 coupling with learned weights. We thus define the networks energy as: $E(x) = - \left(  \sum_{i \ne j} x_i J_{ij} x_j  + \sum_{i} h_i x_i + \sum_{i} A_i x_i x_{i, n-1} \right)$ where $x_i$ is either 1 or -1. This represents one of the distributions forming our joing distribution $P(x_N) = \prod^T_0 P(x_n | x_{t-n})$. We sample $P(x_N)$ by sequentially sampling each timesteps 70x70 network and feeding the output $x_n$ as $x_{n-1}$ into the next timsteps network. Note that from now, we will flip the notation; $u_0$ represents the final distribution and $x_N$ represents the starting distribution or first product in the joint distribution which is pure gaussian noise.

We train the 70x70 network at each time step individually. Like a diffusion model, we add noise to training data using a markov chain; we define the chain such that the data at the final timestep $T$ is pure gaussian noise. We use this markov chain to generate data for time step; we then train each timesteps network on this data to reverse the addition of noise at it's respective time step. For instance, at timestep 5, we would train the model to output $u_{4}$ when fed $u_{5}$). This training is done via the Contrastive Divergence algorthm. See the image below from [1] showing an illustration of the joint distribution sampling (Image A) and a high level hardware implemenentation where each "block" is our 70x70 network (Image B):

<img width="400" height="400" alt="image" src="https://github.com/user-attachments/assets/11e3a7e4-c78b-415e-9cfd-6a18c4bfae59" />

**References**

[1] Andraž Jelinčič et al, "An efficient probabilistic hardware architecture for diffusion-like models" (https://arxiv.org/pdf/2510.23972)
