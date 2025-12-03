function [x, y, alpha] = random_line_in_sector(L, rho_min)
    % generate angle and starting position for user linear track

    alpha = rand()*pi - pi/2;   % choose random angle of movement
    alpha_conj = pi + alpha;    % opposite direction

    if rand() < 0.5             % move forward or backward
        a_tmp = alpha;
        alpha = alpha_conj;
        alpha_conj = a_tmp;
    end
        
    x = cos(alpha_conj)*L/2 + rho_min + L/2; % calculate x starting coordinate
    y = sin(alpha_conj)*L/2;                 % calculate y starting coordinate
 end
