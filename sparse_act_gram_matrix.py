import numpy as np
import torch as th

import pickle

LOAD_FROM_SAVED = False

# feature dictionary

DEV = "cuda"
features = th.randn(10000, 100000, device=DEV)
features /= th.linalg.norm(features, axis=1, keepdims=True)

def sample_activations(batch_size, features, max_act=1, p_act=0.01):
    print(100 / features.shape[0], "p act")
    active = th.rand(batch_size, features.shape[0], device=DEV) < (100 / features.shape[0])
    print("here")
    activation = th.rand(batch_size, features.shape[0], device=DEV) * max_act
    print("there")
    activation[active == False] = 0
    return th.einsum('ij,bi->bj', features, activation)

def calc_gram_matrix(activations):
    return th.einsum('bi,ci->bc', activations, activations)

sample_sizes = [1000]

for sample_size in sample_sizes:
    if LOAD_FROM_SAVED:
        with open('acts.pkl', 'rb') as f:
            acts = pickle.load(f)
    else:
        acts = sample_activations(sample_size, features)

        with open('acts.pkl', 'wb') as f:
            pickle.dump(acts, f)

    print("sampled")

    # fit normal distribution to activations
    means = th.mean(acts, axis=1)
    cov = th.cov(acts)
    cov = cov + th.eye(cov.shape[0], cov.shape[1], device=DEV) * 1e2

    print("fitted")

    # sample from normal distribution
    print(means.shape, cov.shape, sample_size, acts.shape)
    normal_acts = th.distributions.multivariate_normal.MultivariateNormal(means, cov).sample_n((sample_size)).to(DEV)

    if LOAD_FROM_SAVED:
        with open('gram.pkl', 'rb') as f:
            gram = pickle.load(f)
    else:
        gram = calc_gram_matrix(acts)

        with open('gram.pkl', 'wb') as f:
            pickle.dump(gram, f)
    
    # set diagonal to 0
    #gram.fill_diagonal_(0)

    print("grammed")

    #normal_gram = calc_gram_matrix(normal_acts)

    print("normal grammed")

    # flatten gram matrix & plot histogram
    #gram_flat = gram.flatten().cpu().numpy()
    mask = th.ones_like(gram, device=DEV, dtype=th.bool) ^ th.eye(*gram.shape, device=DEV, dtype=th.bool)
    gram_flat = gram[mask].cpu().numpy()
    #normal_gram_flat = normal_gram.flatten()

    # fit normal distribution to gram matrix
    gram_mean = np.mean(gram_flat)
    gram_std = np.std(gram_flat)

    print("gram fitted")

    import matplotlib.pyplot as plt

    print("plotting")

    y, x, _ = plt.hist(gram_flat, bins=200, alpha=0.5, label='sampled', density=True)
    #plt.hist(normal_gram_flat, bins=250, alpha=0.5, label='normal', density=True)

    # take min and max of both histograms
    hist_min = np.min(gram_flat)
    hist_max = np.max(gram_flat)
    mean = np.mean(gram_flat)
    # count things in gram_flat which are greater than and less than 0
    print(np.sum(gram_flat < mean), np.sum(gram_flat > mean), mean)

    # plot normal distribution pdf
    x = np.linspace(hist_min, hist_max, 200)
    plt.plot(x, 1 / (gram_std * np.sqrt(2 * np.pi)) * np.exp( - (x - gram_mean)**2 / (2 * gram_std**2) ), linewidth=2, color='r', label='normal fit')

    ax = plt.gca()
    #ax.set_yscale("function", functions=(lambda x: x**(1/3), lambda x: x**3.0))

    ax.set_ylim(0, y.max())

    plt.legend(loc='upper right')
    plt.savefig("/media/plot.png", dpi=1000)